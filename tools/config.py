"""
正交事件生成管线 - Pydantic 数据模型

镜像 Godot 侧 model/pipeline/ 下的 Resource 类结构。
供 generate_orthogonal_events.py 使用。

数据模型层级：
  TextFeature (基类)
    ├── PromptFeature (风格挂件)
    ├── OptionFeature (选项定义)
    └── FactFeature (事实约束)
  PipelineDimensionValue (基类)
    └── SceneValue (扩展: tags 字段)
  PipelineDimension (维度定义)
    └── 支持 dynamic 派生轴
  DimensionCombo (展开后的维度+值对)
  EventPipelineConfig (根配置)

Registry 模型 (中央特征库):
  TextFeatureLibrary
"""

import json
import os
from pathlib import Path

from pydantic import BaseModel, Field
from typing import Callable, Optional


# ── Registry 目录（tools/） ──
_REGISTRY_DIR = Path(__file__).resolve().parent
_DEFAULT_REGISTRY_PATH = _REGISTRY_DIR / "text_features_registry.json"


class TextFeature(BaseModel):
    """文本特征基类：所有注入 AI Prompt 的文本片段的公共抽象。

    id:   特征的唯一标识
    text: 文本内容（风格指令 / 选项描述 / 事实约束等）
    """
    id: str = ""
    text: str = ""


class PromptFeature(TextFeature):
    """"挂件"：一段纯文本，注入到 AI Prompt 中以微调文本风格。"""
    pass


class NegativeExample(BaseModel):
    """反面教材：告诉 AI「不要做什么」的对照样本。

    field:  指向的约束字段名（如 "action_style" / "resolution_style" / "demand_context"）
    bad:    反面示例文本（AI 应当避免的写法）
    reason: 该示例为什么是错的（解释违背了哪条原则）
    """
    field: str = ""
    bad: str = ""
    reason: str = ""


class NarrativeConstraint(BaseModel):
    """🎯 叙事约束：硬性写作规则 (Narrative Constraint)

    将特定的叙事模式固化为结构化约束，管线以固定格式渲染为独立区块，
    比纯文本 prompt_feature 更难被 AI 忽略。

    所有字段均为可选，可按需单独使用任意组合。
    未来可自由添加新字段，不会破坏已有配置。

    type:              约束类型标签（metadata，仅用于管线 debug / 日志，不参与约束计算）
    demand_context:    约束 event description 中 NPC 如何提出需求（Layer 1: 索取层）
    action_style:      约束 option.text 的写法 / 玩家动作描写（Layer 2: 执行层）
    resolution_style:  约束 failed_hint 的写法 / NPC 揭晓反应（Layer 3: 揭晓层）
    negative_examples: 反面教材列表，每条包含 field/bad/reason
    """
    type: str = ""
    demand_context: str = ""
    action_style: str = ""
    resolution_style: str = ""
    negative_examples: list[NegativeExample] = []


class OptionFeature(TextFeature):
    """选项模板 (ChoiceTemplate)：每个选项的完整定义。

    id:     选项唯一标识，也是 AI 输出字段名
    prompt: AI 指令，告诉 AI 为这个选项生成什么文本
    text:   固定文本（fixed=True）/ AI指令兜底（prompt为空时的 AI 指令）
    result: 选项级结果 DSL，如 "prop_sub(name=career_progress; val=2)"
    requirement: 选项级需求 DSL，如 'poem_has(type=GAN_YE; min_level=1)'
    fixed:  True=固定文本（跳过 AI 生成），False=AI 生成
    accept_influence: 接受的维度影响白名单（dimension ID 列表）。
                      None=接受全部维度影响（向后兼容），
                      []=拒绝所有维度影响（如"拂袖而去"类选项），
                      ["dim_A"]=只接受指定维度的 scale + operator_dsl。
    narrative_constraint: 结构化叙事约束（可选），如 blind_box_transaction
    plugins: 插件配置挂载点（可选），key=插件ID, value=插件自定义结构
             如 {"failed_hint": {"style": "mock_direct_speech", "max_chars": 20}}

    narrative_constraint 的字段全部可选，按需使用。
    管线 build_user_prompt() 只渲染非空字段到 "📜 写作契约" 区块。
    plugins 字段由插件在 init() 阶段扫描使用，管线不直接消费。
    """
    result: str = ""
    requirement: str = ""
    fixed: bool = False
    prompt: str = ""
    accept_influence: Optional[list[str]] = Field(
        default=None,
        description="接受的维度影响白名单（dimension ID 列表）。None=接受全部（向后兼容）",
    )
    narrative_constraint: Optional[NarrativeConstraint] = None
    plugins: dict[str, dict] = Field(
        default_factory=dict,
        description="插件级配置挂载点: {plugin_id: {config_dict}}",
    )


class FactFeature(TextFeature):
    """事实约束：AI 必须严格遵循的事实陈述，不得编造。

    id:   事实的唯一标识，如 "bai_ye_venue"
    text: 事实陈述，如 "去拜谒的地方可以是王府或者右相府"
    """
    pass


class TextFeatureLibrary(BaseModel):
    """文本特征中央库：从 text_features_registry.json 加载的完整特征集合。

    加载器通过 _FEATURE_KEY_MAP 将 JSON 中的 prompt_features /
    fact_features / option_features 三个数组按 id 索引为 dict，
    供 resolve_text_features() 快速 O(1) 查找。
    """
    prompt_features: list[PromptFeature] = []
    fact_features: list[FactFeature] = []
    option_features: list[OptionFeature] = []

    # 按 id 索引的内部缓存，由 _build_index() 填充
    _prompt_index: dict[str, PromptFeature] = {}
    _fact_index: dict[str, FactFeature] = {}
    _option_index: dict[str, OptionFeature] = {}

    def model_post_init(self, __context):
        """Pydantic v2 初始化钩子：加载完成后建立索引。"""
        self._build_index()

    def _build_index(self):
        """将列表按 id 建立 dict 索引以便 O(1) 查找。"""
        self._prompt_index = {f.id: f for f in self.prompt_features}
        self._fact_index = {f.id: f for f in self.fact_features}
        self._option_index = {f.id: f for f in self.option_features}

    def resolve_prompt(self, key: str) -> PromptFeature:
        if key not in self._prompt_index:
            raise KeyError(f"TextFeatureLibrary 中未找到 prompt_feature: '{key}'")
        return self._prompt_index[key]

    def resolve_fact(self, key: str) -> FactFeature:
        if key not in self._fact_index:
            raise KeyError(f"TextFeatureLibrary 中未找到 fact_feature: '{key}'")
        return self._fact_index[key]

    def resolve_option(self, key: str) -> OptionFeature:
        if key not in self._option_index:
            raise KeyError(f"TextFeatureLibrary 中未找到 option_feature: '{key}'")
        return self._option_index[key]


# ── 特征字段名 → 索引名 / resolve 方法名的映射表 ──
_FEATURE_KEY_MAP: dict[str, tuple[str, str]] = {
    "prompt_features": ("_prompt_index", "resolve_prompt"),
    "fact_features":   ("_fact_index",   "resolve_fact"),
    "option_features": ("_option_index", "resolve_option"),
}


def load_text_features_library(
    registry_path: str | Path | None = None,
) -> TextFeatureLibrary:
    """从 JSON 文件加载 TextFeature 中央库。

    参数:
        registry_path: JSON 文件路径，默认 tools/text_features_registry.json

    返回:
        TextFeatureLibrary 实例（已建立索引）
    """
    path = Path(registry_path) if registry_path else _DEFAULT_REGISTRY_PATH
    if not path.exists():
        raise FileNotFoundError(
            f"TextFeature 注册文件不存在: {path}"
        )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return TextFeatureLibrary.model_validate(data)


def resolve_text_features(
    config_data: dict,
    library: TextFeatureLibrary | None = None,
) -> dict:
    """将 config_data 中的 TextFeature key 列表解析为完整对象。

    遍历 config_data 中 _FEATURE_KEY_MAP 定义的字段名，
    如果字段值是 list[str]（key 列表），则从 library 中
    按 key 查找替换为 list[PromptFeature|FactFeature|OptionFeature]。

    参数:
        config_data: 从 JSON 加载的原始配置 dict
        library:     已加载的 TextFeatureLibrary；为 None 时自动加载

    返回:
        修改后的 config_data（原 dict 已原地修改，也返回引用方便链式调用）

    引发:
        KeyError: 某个 key 在 library 中不存在
    """
    if library is None:
        library = load_text_features_library()

    for field_name, (_index_attr, resolve_method) in _FEATURE_KEY_MAP.items():
        raw = config_data.get(field_name)
        if raw is None:
            continue  # 字段不存在 → 跳过

        # 只有 list[str] 需要 resolve；list[dict] 保持原样（向后兼容）
        if not raw or not isinstance(raw[0], str):
            continue

        resolved = []
        for key in raw:
            fn = getattr(library, resolve_method)
            resolved.append(fn(key))
        config_data[field_name] = resolved

    return config_data


class PipelineDimensionValue(BaseModel):
    """维度值：正交矩阵中的一个具体节点。
    
    tags 字段主要用于 SceneValue 场景，但放在基类避免 Pydantic
    反序列化时丢失字段。非场景值的 tags 默认空列表，无影响。
    
    narrative_constraint: 可选的结构化叙事约束，描述该维度值对应的
        NPC 行为、玩家动作、揭晓方式和反面教材。
        当维度值的 description 字段包含文学叙事时，建议将约束拆解到
        narrative_constraint 中，避免样例过拟合（few-shot overfitting）。
    """
    id: str = ""
    name: str = ""
    description: str = ""
    scale: float = 1.0
    operator_dsl: str = ""
    tags: list[str] = []  # Dynamic Dimension 用：预定义标签 ID 列表
    narrative_constraint: Optional[NarrativeConstraint] = None


class SceneValue(PipelineDimensionValue):
    """场景维度值：PipelineDimensionValue 的别名类型。
    
    语义标记类型：标识这个维度值是一个"场景"。
    tags 字段继承自基类，存储场景的预定义标签 ID
    （如 "env_society_festival", "vibe_aesthetic_sensual"），
    供 Dynamic Dimension 的 Extractor 函数提取使用。
    """
    pass


class PipelineDimension(BaseModel):
    """维度定义：正交矩阵中的一个轴。
    
    dynamic=True 时，该轴的值不是预先定义在 values 中，而是
    通过 EXTRACTOR_REGISTRY 中的 value_extractor_key 函数，
    在展开笛卡尔积时根据其他已确定的轴动态派生。
    """
    id: str = ""
    name: str = ""
    description: str = ""
    values: list[PipelineDimensionValue] = []

    # Dynamic Dimension 支持
    dynamic: bool = False
    value_extractor_key: str = ""
    value_extractor_config: dict = {}


class DimensionCombo(BaseModel):
    """展开后的维度组合对：一个已选中的维度定义 + 选中的维度值。
    
    替代 build_user_prompt 中硬编码的 d1/dv1/d2/dv2/d3/dv3 参数，
    使其支持任意数量的维度。
    
    dimension: 维度定义（如 "场景" 维度）
    value:     该维度下选中的具体值（如 "长安夜宴"）
    """
    dimension: PipelineDimension
    value: PipelineDimensionValue


class EventPipelineConfig(BaseModel):
    """事件库生成配置：一个事件库的完整配置。"""
    id: str = ""
    name: str = ""

    # AI Prompt 组件
    background_context: str = ""
    ai_persona: str = ""
    prompt_features: list[PromptFeature] = []

    # 事实约束（AI 必须严格遵循，不得编造）
    fact_features: list[FactFeature] = []

    # 选项定义（让 AI 生成选项文本）
    option_features: list[OptionFeature] = []

    # 正交维度
    dimensions: list[PipelineDimension] = []

    # 通用触发标签（CSV context 列的 trigger_tags）
    # 列表中的字符串会作为事件的触发标签，格式为:
    #   单标签: trigger_tags=bai_ye|weight=10
    #   多标签: trigger_tags=[tag1/tag2]|weight=10
    # 默认 ["bai_ye"] 保持向后兼容。
    universal_tags: list[str] = ["bai_ye"]

    # 通用事件 requirement（CSV requirements 列）
    # 使用 prop_gt/prop_lt/prop_eq 等属性比较 DSL，
    # 多个表达式用逗号分隔（AND 逻辑）。
    # 默认空字符串表示不添加 requirement。
    # 例如: "prop_gt(name=ambition,val=0),prop_lt(name=ambition,val=70)"
    universal_requirement: str = ""

    # 通用选项结果（类似 universal_requirement，但作用于每个选项的 results 列）
    # 使用 prop_add/prop_sub/prop_set 等属性操作 DSL，
    # 多个表达式用 | 分隔（Layer 0 OR 逻辑），
    # 最终会和维度缩放后的 DSL 合并。
    # 例如: "prop_add(name=career_progress; val=1)"
    universal_result: str = ""

    # 通用选项 requirement（CSV option 行的 requirements 列）
    # 使用 poem_has 等 requirement DSL，支持模板变量 {failed_hint}，
    # 该变量会被插件动态注入的 failed_hint 字段替换。
    # 默认空字符串表示不添加选项级 requirement。
    # 例如: "poem_has(type=GAN_YE; min_level=1; failed_hint=\"{failed_hint}\")"
    universal_option_requirement: str = ""

    # Plugin Hook 系统：启用的插件 ID 列表
    # 每个 ID 对应 PLUGIN_REGISTRY 中已注册的 EventPromptPlugin 实例。
    # 插件在以下 3 个 Hook 点注入行为:
    #   1. get_prompt_fragment() — User Prompt 注入额外指令
    #   2. get_extra_output_fields() — 声明额外解析字段
    #   3. enrich_context() — 富化 CSV context 列
    # 示例: ["failed_hint"]
    plugins: list[str] = []

    # 生成参数
    word_count_min: int = 80
    word_count_max: int = 200
    max_retries: int = 3
    api_model: str = "deepseek-chat"
    output_dir: str = "data/generated_events/"
