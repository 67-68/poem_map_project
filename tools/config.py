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
  PipelineDimension (维度定义)
    └── 支持 linked_value_ids 值级引用 + DEPRECATED dynamic 派生轴
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


class EmotionPairBranch(BaseModel):
    """情绪对分支定义：一个选项分支绑定的情绪。

    emotion: 情绪 ID，如 "ARROGANCE", "TRANQUILITY"
    desc:    情绪的中文描述，如 "狂傲", "静谧"
    """
    emotion: str = ""
    desc: str = ""


class EmotionPairConfig(BaseModel):
    """情绪对配置：定义一对精英选项 + 一个降级选项的情绪绑定。

    branch_A: 精英分支 A — 通常对应 狂客 选项
    branch_B: 精英分支 B — 通常对应 钻营 选项
    fallback: 降级分支   — 通常对应 逢迎 选项
    """
    branch_A: EmotionPairBranch = Field(default_factory=EmotionPairBranch)
    branch_B: EmotionPairBranch = Field(default_factory=EmotionPairBranch)
    fallback: EmotionPairBranch = Field(default_factory=EmotionPairBranch)


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
    operator_dsl: str = Field(
        default="",
        description="选项级 Operator DSL，如 'prop_add(name=talent; val=5) | emo_add(name=TRANQUILITY; val=10)'。"
                    "由 OperatorSemanticTranslator 翻译为语义锚点注入 Prompt。",
    )
    plugins: dict[str, dict] = Field(
        default_factory=dict,
        description="插件级配置挂载点: {plugin_id: {config_dict}}",
    )
    pair_role: str = Field(
        default="",
        description="情绪对角色: 'branch_A' | 'fallback' | 'branch_B'。"
                    "空字符串表示不使用 emotion_pair 意象绑定。",
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
    
    linked_value_ids: 跨维度值引用列表。当该值被选中时，引用的维度值
        会以覆盖模式替换对应维度的槽位。所有 linked_value_ids 必须
        指向同一目标维度，且不能指向自身所属的维度。
        示例：["TypeA"] 表示"当此值选中时，资源掠夺维度固定为 TypeA"。
    
    virtual_dimension_ids: 虚拟维度追加列表。每个 inner list 成为一个
        额外的虚拟维度，与所有原始维度做笛卡尔积。不替换任何现有维度。
        每个 inner list 中的字符串是外部维度库中的维度值 ID，
        如 ["identity_qingliu_owner", "identity_qingliu_official"]。
    
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
    option_results: dict[str, str] = {}
    linked_value_ids: list[str] = []
    virtual_dimension_ids: list[list[str]] = []
    tags: list[str] = []
    stored_to: str = ""
    narrative_constraint: Optional[NarrativeConstraint] = None


class BlacklistDimensionConfig(BaseModel):
    """维度级滑动黑名单配置。

    挂载到 PipelineDimension.blacklist_config，表示该维度启用黑名单机制。
    配置驱动 tracked_field（如 summary.description），运行时自动注入 prompt
    并维护每个维度值的生成摘要历史。

    约束：一个 EventPipelineConfig 中最多只有一个维度挂载 blacklist_config。
    """
    tracked_field: str = Field(
        default="description",
        description="黑名单追踪的字段名（如 'description'），运行时会在输出格式中自动追加 summary.<tracked_field>",
    )
    tracked_field_description: str = Field(
        default="",
        description="对 tracked_field 的中文语义描述，用于黑名单 prompt 说明 AI 应该总结什么",
    )
    max_items: int = Field(
        default=20,
        ge=1,
        description="黑名单滑动窗口最大条目数。超出时丢弃最老的条目。",
    )


class PipelineDimension(BaseModel):
    """维度定义：正交矩阵中的一个轴。
    
    新版使用 linked_value_ids 在 PipelineDimensionValue 级别做值级引用。
    
    value_extractor_config: [DEPRECATED] 保留供内联计算读取的配置 dict。
    """
    id: str = ""
    name: str = ""
    description: str = ""
    values: list[PipelineDimensionValue] = []

    # 维度级滑动黑名单
    blacklist_config: Optional[BlacklistDimensionConfig] = None


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

    # 🆕 era 标识：所属时代，如 "745_ambition"
    # 生成事件时会自动注入 CSV context 列的 era=<value>，供 Godot 端路由使用。
    era: str = ""

    # 🆕 archetype 标识：事件类型标签（如 "baiye"）
    # 对应 tools/data/event_archetypes.json 中的 key。
    # 生成事件时会自动注入 CSV context 列的 archetype=<value>，
    # Godot 端解析后翻译为 BaseRequirements + ChoiceResult 存入 RandomEvent。
    # 空字符串表示该事件无类型标签。
    archetype_id: str = ""

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

    # 核心指令（final_directive）：渲染到 system prompt 绝对末尾
    # 利用 Recency Bias：最后一行约束最强。禁止使用心理动词等强约束放这里。
    final_directive: str = ""

    # 生成参数
    word_count_min: int = 80
    word_count_max: int = 200
    # 选项字数上限（校验阈值）。AI prompt 提示值通过自适应收缩动态调整，校验始终以此值为准
    option_word_count_max: int = 30
    max_retries: int = 3
    api_model: str = "deepseek-chat"
    output_dir: str = "data/generated_events/"

    # 🆕 本地情绪注册表（覆盖全局 semantic_emotions.json）
    # key = emotion 枚举名（如 "TRANQUILITY"）
    # value = {"cn_name": "旷达", "description": "超脱物外的淡然与通透"}
    # 未在此处定义的 emotion 将 fallback 到全局数据文件
    emotion_registry: dict = Field(
        default_factory=dict,
        description="本地情绪注册表，覆盖 global semantic_emotions.json fallback。"
                    "可含 _note 等元信息字段，实际情绪条目为 {emotion_name: {cn_name, description}}",
    )

    # 🆕 语义锚点开关
    # 启用后，operator_translator 会将 option_features[].operator_dsl 和
    # dimensions[].values[].operator_dsl 翻译为语义锚点注入 Prompt
    semantic_anchors: dict = Field(
        default_factory=dict,
        description="语义锚点配置: {'enabled': True} 启用翻译。"
                    "可含 _note 等元信息字段",
    )

    # 🆕 意象正交打分开关
    # True → 提取维度 tags 的意象池 → 按情绪亲缘度打分 → 注入 Prompt
    # False（默认）→ 完全向后兼容，不执行意象相关逻辑
    apply_dimension_imagery: bool = False

    # 🆕 情绪对定义字典
    # key = emotion_pair_id (如 "pair_rebellion")
    # value = EmotionPairConfig 定义 branch_A / branch_B / fallback 的情绪绑定
    # 用于多态事件库：每个 humiliation_type 维度值携带 emotion_pair_id，
    # 每个 option_feature 通过 pair_role 查询对应情绪，做 per-option 意象打分。
    emotion_pairs: dict[str, EmotionPairConfig] = Field(
        default_factory=dict,
        description="情绪对定义字典: {pair_id: EmotionPairConfig}",
    )

    # 🆕 沙盒关键词生成提示：一段附加指令文本，注入到 SandboxManager 的
    # _generate_keywords_for() 的 user_prompt 中，作为创作指引。
    # 接受 PromptFeature（id + text），text 不为空时生效。
    # JSON 配置中 inline 定义即可，无需走中央 registry 解析。
    sandbox_feature: Optional[PromptFeature] = None

    # 🆕 插件专属配置字典
    # key = plugin_id (如 "emotion_pair_imagery")
    # value = 该插件的自定义配置 dict
    # 插件在 init() 中通过 cfg.plugin_config.get(self.plugin_id, {}) 读取
    # 示例:
    #   "plugin_config": {
    #     "emotion_pair_imagery": {
    #       "emotion_dimension_id": "emotion",
    #       "scene_dimension_id": "scene_climb"
    #     }
    #   }
    plugin_config: dict[str, dict] = Field(
        default_factory=dict,
        description="插件专属配置字典: {plugin_id: {config_key: config_value}}",
    )


class ImageryItem(BaseModel):
    """意象实体：28个意象的情绪亲缘度映射。"""
    id: str = ""                    # "ENV_NATURE_NIGHTMOON:cold_moon"
    name: str = ""                  # "寒月"
    description: str = ""           # 意象的文学内涵介绍，供 AI Prompt 使用
    affinities: dict[str, int] = {} # {"TRANQUILITY": 90, "SORROW": 80, ...}


# ════════════════════════════════════════════════════════════════
# 内置示例配置（拜谒 - 蜜月期）
# ════════════════════════════════════════════════════════════════

def default_config() -> EventPipelineConfig:
    """返回默认的拜谒蜜月期配置。"""
    return EventPipelineConfig(
        id="bai_ye_honeymoon",
        name="拜谒 - 蜜月期 (0-70)",
        background_context="""
大唐天宝年间（公元742年—756年），长安城。此时正值唐玄宗在位后期，朝政日益腐败，权相李林甫把持朝纲，官场中充斥着"口蜜腹剑"的风气。

玩家是初入仕途的进士，需要在长安城中通过拜谒权贵来获得举荐和升迁机会。权贵府邸门前，从门子到清客到权贵本人，层层关卡都需要打点。这是一个表面上讲究礼数、实则处处要钱的世界。

蜜月期（玩家野心值0-70）：这个阶段玩家尚处于对官场的幻想期，遇到的阻碍虽然令人不快，但还没有到彻底打破幻想的程度。对方多少还保留着表面上的客气和礼数。
""".strip(),
        ai_persona="""
你是一位精通唐朝官场文化和人情世故的叙事设计师。你擅长用克制、白描的手法呈现官场中微妙的权力关系。你的文风接近唐传奇，简洁有力，不煽情不议论，让事实本身说话。你深刻理解"无状态叙事"——每个事件都是独立的切片，不依赖玩家的过往经历。
""".strip(),
        prompt_features=[
            PromptFeature(id="stateless_narrative", text="使用无状态叙事，不要引用玩家过去的具体经历，每次事件都当作第一次发生。"),
            PromptFeature(id="tone_cautious", text="不要过于戏剧化，保持冷静克制的叙事语气，突出官场的虚伪和客套。"),
        ],
        fact_features=[
            FactFeature(id="bai_ye_venue", text="去拜谒的地方可以是王府、右相府或六部衙门，这些地点在长安城中真实存在。"),
        ],
        dimensions=[
            PipelineDimension(
                id="power_level",
                name="权力阻击位",
                description="玩家拜谒时面对的门槛等级，级别越高付出的代价越大",
                values=[
                    PipelineDimensionValue(
                        id="L0", name="门子/家奴",
                        description="最底层的门卫、仆役，守门索贿，玩家需要打点才能进门",
                        scale=1.0,
                        operator_dsl='prop_sub(name=money; val=10)',
                    ),
                    PipelineDimensionValue(
                        id="L1", name="清客/文法吏",
                        description="中层幕僚、文书小吏，递话要钱，比直接面对权贵便宜",
                        scale=1.5,
                        operator_dsl='prop_sub(name=money; val=10)',
                    ),
                    PipelineDimensionValue(
                        id="L2", name="权贵本尊",
                        description="直接面对高官权贵，需要重大代价才能获得见面机会",
                        scale=2.0,
                        operator_dsl='prop_sub(name=money; val=10)|prop_sub(name=fatigue; val=5)',
                    ),
                ],
            ),
            PipelineDimension(
                id="extraction_type",
                name="资源掠夺机制",
                description="玩家在这次拜谒中付出的主要代价类型",
                values=[
                    PipelineDimensionValue(
                        id="TypeA", name="金钱掠夺",
                        description="对方通过明示或暗示索取钱财，这是最常见的资源掠夺方式",
                        scale=1.0,
                        operator_dsl='prop_sub(name=money; val=20)',
                    ),
                    PipelineDimensionValue(
                        id="TypeB", name="生命/健康损耗",
                        description="对方耗着玩家、让玩家长时间等候、带病工作等身体损耗",
                        scale=1.0,
                        operator_dsl='prop_sub(name=health; val=5)',
                    ),
                    PipelineDimensionValue(
                        id="TypeC", name="精神PUA",
                        description="对方通过羞辱、冷落、贬低玩家地位来获取精神快感",
                        scale=1.0,
                        operator_dsl='prop_sub(name=fatigue; val=10)',
                    ),
                ],
            ),
            PipelineDimension(
                id="evil_motive",
                name="平庸之恶动机",
                description="对方为难玩家的内在动机，这决定了事件的道德底色",
                values=[
                    PipelineDimensionValue(
                        id="M0", name="媚上邀功",
                        description="对方为了讨好上级而故意为难玩家，把玩家当投名状",
                        scale=1.0,
                        operator_dsl="",
                    ),
                    PipelineDimensionValue(
                        id="M1", name="纯粹寻租/变态",
                        description="对方纯粹为了享受支配欲和权力快感，毫无制度性理由",
                        scale=1.5,
                        operator_dsl="",
                    ),
                    PipelineDimensionValue(
                        id="M2", name="制度性冷漠",
                        description="对方并非刻意针对玩家，而是制度本身如此，玩家只是碰上了",
                        scale=1.0,
                        operator_dsl="",
                    ),
                ],
            ),
        ],
        word_count_min=80,
        word_count_max=200,
        max_retries=3,
        api_model="deepseek-reasoner",
        output_dir="data/generated_events/",
    )


# ════════════════════════════════════════════════════════════════
# JSON 配置加载器
# ════════════════════════════════════════════════════════════════

_EXT_DIM_DB_PATH = _REGISTRY_DIR / "imagery_dimension_db.json"


def _collect_unique_linked_ids(dimensions: list[dict]) -> set[str]:
    """收集所有维度值中的 linked_value_ids 和 virtual_dimension_ids 内层 ID（去重）。

    virtual_dimension_ids 中的每个 inner list 的每个 ID 都会被收集，
    用于后续自动注入外部维度。"""
    ids: set[str] = set()
    for dim in dimensions:
        for val in dim.get("values", []):
            for linked_id in val.get("linked_value_ids", []):
                ids.add(linked_id)
            for inner_list in val.get("virtual_dimension_ids", []):
                for vid in inner_list:
                    ids.add(vid)
    return ids


def _load_external_dimension_db() -> list[dict]:
    """从 imagery_dimension_db.json 加载外部维度库，返回 PipelineDimension 兼容的 dict 列表。

    文件结构（通用维度容器）:
        { "dimensions": [ { "id": ..., "name": ..., "values": [...] }, ... ] }
    """
    if not _EXT_DIM_DB_PATH.exists():
        raise FileNotFoundError(
            f"外部维度数据库不存在: {_EXT_DIM_DB_PATH}，"
            f"请确保工具目录下存在该文件"
        )
    with open(_EXT_DIM_DB_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("dimensions", [])


def _build_value_id_to_dim_index(
    dimensions: list[dict],
) -> dict[str, int]:
    """构建 value_id → dimension_index 的映射（用于 O(1) 查找）。"""
    idx: dict[str, int] = {}
    for dim_i, dim in enumerate(dimensions):
        for val in dim.get("values", []):
            idx[val["id"]] = dim_i
    return idx


def _resolve_linked_value_ids(data: dict):
    """解析 dimensions 中的 linked_value_ids：若引用的 ID 不在现有维度中，
    从外部维度数据库查找并自动注入匹配的维度。

    通用设计：数据库可包含任意多个维度定义，按需自动注入。
    """
    dimensions: list[dict] = data.get("dimensions", [])
    if not dimensions:
        return

    linked_ids = _collect_unique_linked_ids(dimensions)
    if not linked_ids:
        return  # 没有 linked_value_ids，无需处理

    # 构建现有维度值的 ID 索引
    existing_idx = _build_value_id_to_dim_index(dimensions)
    existing_dim_ids = {d["id"] for d in dimensions}

    # 检查是否有 linked_id 不在现有维度中
    missing = linked_ids - set(existing_idx.keys())
    if not missing:
        return  # 所有引用都已满足

    # 加载外部维度数据库
    ext_dims = _load_external_dimension_db()
    ext_idx = _build_value_id_to_dim_index(ext_dims)
    ext_dim_ids = {d["id"] for d in ext_dims}

    # 检查缺失的 ID 是否在外部数据库中有对应
    still_missing = missing - set(ext_idx.keys())
    if still_missing:
        raise KeyError(
            f"linked_value_ids 中引用的值 {sorted(still_missing)} "
            f"既不在现有维度中，也不在外部维度数据库 "
            f"({_EXT_DIM_DB_PATH}) 中"
        )

    # 确定需要注入的外部维度（按所属维度分组去重）
    dim_ids_to_inject: set[str] = set()
    for linked_id in missing:
        ext_dim_i = ext_idx[linked_id]
        dim_ids_to_inject.add(ext_dims[ext_dim_i]["id"])

    # 去重：跳过已存在的维度
    for dim_id in dim_ids_to_inject:
        if dim_id in existing_dim_ids:
            continue
        # 从外部数据库中找到完整定义
        ext_dim = next(d for d in ext_dims if d["id"] == dim_id)
        dimensions.append(ext_dim)
        print(f"  🗄️  自动注入外部维度 '{dim_id}' "
              f"({len(ext_dim.get('values', []))} 个值)，"
              f"满足 linked_value_ids 引用")


def load_config_from_json(path: str) -> EventPipelineConfig:
    """从 JSON 文件加载配置，自动解析 TextFeature key 为完整对象。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 如果 prompt_features / fact_features / option_features
    # 是 list[str]（key 列表），从中央特征库解析为完整对象
    resolve_text_features(data)

    # 解析 narrative_constraint 中的 text feature key
    # 将 demand_context / action_style 等字段的 key 引用解析为实际文本
    # 注意：resolve_text_features() 已将 list[str] 转为 Pydantic 对象，
    # 所以要先检查类型再决定用 .get() 还是 .getattr()
    library = load_text_features_library()
    for opt in data.get("option_features", []):
        if isinstance(opt, dict):
            nc = opt.get("narrative_constraint")
        else:
            nc = getattr(opt, "narrative_constraint", None)
        if not nc:
            continue
        if isinstance(nc, dict):
            nc_dict = nc
        else:
            # Pydantic BaseModel → dict
            nc_dict = nc.model_dump()
        for field in ("demand_context", "action_style", "resolution_style"):
            val = nc_dict.get(field, "")
            if not val or not isinstance(val, str):
                continue
            # 如果该值在 prompt_features 中有对应 entry，则解析为实际文本
            try:
                feature = library.resolve_prompt(val)
                nc_dict[field] = feature.text
            except KeyError:
                pass  # 不是 key 引用，保持原值（向后兼容 inline text）
        # 如果是 Pydantic 对象，将更新后的 dict 写回
        if not isinstance(opt, dict) and isinstance(nc, dict):
            for field in ("demand_context", "action_style", "resolution_style"):
                if field in nc_dict:
                    setattr(nc, field, nc_dict[field])

    # ════════════════════════════════════════════════════════════════
    # 🆕 自动解析 linked_value_ids：若引用的值不在现有维度中，
    #    从意象维度数据库注入 imagery 维度
    # ════════════════════════════════════════════════════════════════
    _resolve_linked_value_ids(data)

    return EventPipelineConfig.model_validate(data)
