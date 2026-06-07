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
"""

from pydantic import BaseModel, Field
from typing import Callable, Optional


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


class OptionFeature(TextFeature):
    """选项定义：指定一个选项的标识和 AI 生成指令。

    id: 选项的唯一标识（uuid key），如 "option_accept"
    text: AI 指令，如 "用15字以内描述接受贿赂的方案"
    """
    pass


class FactFeature(TextFeature):
    """事实约束：AI 必须严格遵循的事实陈述，不得编造。

    id:   事实的唯一标识，如 "bai_ye_venue"
    text: 事实陈述，如 "去拜谒的地方可以是王府或者右相府"
    """
    pass


class PipelineDimensionValue(BaseModel):
    """维度值：正交矩阵中的一个具体节点。
    
    tags 字段主要用于 SceneValue 场景，但放在基类避免 Pydantic
    反序列化时丢失字段。非场景值的 tags 默认空列表，无影响。
    """
    id: str = ""
    name: str = ""
    description: str = ""
    scale: float = 1.0
    operator_dsl: str = ""
    tags: list[str] = []  # Dynamic Dimension 用：预定义标签 ID 列表


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

    # 生成参数
    word_count_min: int = 80
    word_count_max: int = 200
    max_retries: int = 3
    api_model: str = "deepseek-chat"
    output_dir: str = "data/generated_events/"
