"""
正交事件生成管线 - Pydantic 数据模型

镜像 Godot 侧 model/pipeline/ 下的 Resource 类结构。
供 generate_orthogonal_events.py 使用。
"""

from pydantic import BaseModel, Field
from typing import Optional


class PromptFeature(BaseModel):
    """"挂件"：一段纯文本，注入到 AI Prompt 中以微调文本风格。"""
    id: str = ""
    text: str = ""


class PipelineDimensionValue(BaseModel):
    """维度值：正交矩阵中的一个具体节点。"""
    id: str = ""
    name: str = ""
    description: str = ""
    scale: int = 1
    operator_dsl: str = ""


class PipelineDimension(BaseModel):
    """维度定义：正交矩阵中的一个轴。"""
    id: str = ""
    name: str = ""
    description: str = ""
    values: list[PipelineDimensionValue] = []


class EventPipelineConfig(BaseModel):
    """事件库生成配置：一个事件库的完整配置。"""
    id: str = ""
    name: str = ""

    # AI Prompt 组件
    background_context: str = ""
    ai_persona: str = ""
    prompt_features: list[PromptFeature] = []

    # 正交维度
    dimensions: list[PipelineDimension] = []

    # 通用事件 requirement（CSV requirements 列）
    # 使用 prop_gt/prop_lt/prop_eq 等属性比较 DSL，
    # 多个表达式用逗号分隔（AND 逻辑）。
    # 默认空字符串表示不添加 requirement。
    # 例如: "prop_gt(name=ambition,val=0),prop_lt(name=ambition,val=70)"
    universal_requirement: str = ""

    # 生成参数
    word_count_min: int = 80
    word_count_max: int = 200
    max_retries: int = 3
    api_model: str = "deepseek-chat"
    output_dir: str = "data/generated_events/"
