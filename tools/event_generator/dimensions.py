"""
Dynamic Dimension 系统 — 业务逻辑域。

包含:
  EXTRACTOR_REGISTRY   全局 Extractor 函数注册表
  register_extractor   注册函数
  _extract_scene_tags  场景标签提取器
  expand_combinations  笛卡尔积展开（支持 Dynamic Dimension）
  _make_combos         维度定义列表 + 值元组 → DimensionCombo 列表
"""

import itertools
from typing import Callable

from tools.config import DimensionCombo, PipelineDimension, PipelineDimensionValue


# ════════════════════════════════════════════════════════════════
# Extractor Registry — 动态维度值派生函数注册表
# ════════════════════════════════════════════════════════════════

EXTRACTOR_REGISTRY: dict[str, Callable] = {}


def register_extractor(key: str, fn: Callable):
    """注册一个 Extractor 函数到全局注册表。"""
    EXTRACTOR_REGISTRY[key] = fn


def _extract_scene_tags(
    context: dict,
    config: dict,
) -> list[PipelineDimensionValue]:
    """从 context 中寻找带 tags 的维度值，提取 tags 生成派生维度值。

    遍历 context["dimensions"]，找到第一个有非空 tags 的维度值，
    提取其 tags 字段，过滤掉 exclude 列表中的标签，
    将每个剩余 tag 映射为一个 PipelineDimensionValue。

    context = {"dimensions": {"scene": PipelineDimensionValue(tags=[...]), ...}}
    config  = {"exclude": ["action_main_baiye"]}
    """
    for dim_id, dv in context["dimensions"].items():
        if dv.tags:
            exclude = set(config.get("exclude", []))
            filtered = [t for t in dv.tags if t not in exclude]
            return [
                PipelineDimensionValue(
                    id=t, name=t, description=f"场景标签: {t}",
                    scale=1.0, operator_dsl="",
                )
                for t in filtered
            ]
    return []  # 无合法派生值 → 跳过该场景组合


register_extractor("scene_tags", _extract_scene_tags)


# ════════════════════════════════════════════════════════════════
# 笛卡尔积展开
# ════════════════════════════════════════════════════════════════

def expand_combinations(
    dimensions: list[PipelineDimension],
    registry: dict[str, Callable] | None = None,
):
    """展开所有维度组合，支持 Dynamic Dimension。

    1. 分离 static dims 和 dynamic dims
    2. static dims 正常笛卡尔积
    3. 对每个 static 组合，调用 Extractor 获取 dynamic 派生值
    4. static × dynamic 产生最终组合

    Yields:
        tuple[PipelineDimensionValue, ...]: 一个完整组合的维度值元组
    """
    registry = registry or EXTRACTOR_REGISTRY
    static_dims = [d for d in dimensions if not d.dynamic]
    dynamic_dims = [d for d in dimensions if d.dynamic]

    for static_values in itertools.product(*[d.values for d in static_dims]):
        # 构建上下文
        context = {
            "dimensions": {
                dim.id: val
                for dim, val in zip(static_dims, static_values)
            }
        }

        if not dynamic_dims:
            yield static_values
            continue

        # 解析 dynamic dims
        dynamic_value_lists = []
        skip = False
        for dyn_dim in dynamic_dims:
            if dyn_dim.value_extractor_key and dyn_dim.value_extractor_key in registry:
                derived = registry[dyn_dim.value_extractor_key](
                    context, dyn_dim.value_extractor_config,
                )
                if not derived:
                    skip = True
                    break
                dynamic_value_lists.append(derived)
            else:
                # fallback: 无注册的 extractor，用静态 values（降级为非动态）
                dynamic_value_lists.append(dyn_dim.values)

        if skip:
            continue  # 该 static 组合无合法 dynamic 派生值

        # static × dynamic 完整组合
        for dyn_values in itertools.product(*dynamic_value_lists):
            yield static_values + dyn_values


# ════════════════════════════════════════════════════════════════
# DimensionCombo 组装
# ════════════════════════════════════════════════════════════════

def _make_combos(
    dimensions: list[PipelineDimension],
    values: tuple[PipelineDimensionValue, ...],
) -> list[DimensionCombo]:
    """将维度定义列表和对应的值元组组装为 DimensionCombo 列表。"""
    if len(dimensions) != len(values):
        raise ValueError(
            f"dimensions ({len(dimensions)}) and values ({len(values)}) length mismatch"
        )
    return [
        DimensionCombo(dimension=dim, value=val)
        for dim, val in zip(dimensions, values)
    ]
