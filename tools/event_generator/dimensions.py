"""
Dynamic Dimension 系统 — 业务逻辑域（重构版）。

包含:
  expand_combinations  笛卡尔积展开（支持 linked_value_ids 值级引用）
  _find_value_by_id    按 ID 查找维度值（内部辅助）
  _make_combos         维度定义列表 + 值元组 → DimensionCombo 列表
"""

import itertools

from tools.config import DimensionCombo, PipelineDimension, PipelineDimensionValue


# ════════════════════════════════════════════════════════════════
# 内部辅助函数
# ════════════════════════════════════════════════════════════════

def _find_value_by_id(
    dimensions: list[PipelineDimension],
    value_id: str,
) -> tuple[int, PipelineDimensionValue]:
    """在所有维度的所有值中查找指定 ID 的维度值。

    Returns:
        (dim_index, value) 元组

    Raises:
        ValueError: 未找到该 ID 的值
    """
    for dim_idx, dim in enumerate(dimensions):
        for val in dim.values:
            if val.id == value_id:
                return dim_idx, val
    raise ValueError(
        f"linked_value_ids 中引用的值 '{value_id}' 未在任何维度中找到"
    )


def _validate_linked_value_ids(dimensions: list[PipelineDimension]):
    """校验 linked_value_ids 的全局约束。

    规则:
      1. 最多只有一个维度的值使用了 linked_value_ids（「主维度」约束）
      2. 每个 linked_value_ids 指向的值必须存在
      3. linked_value_ids 不能指向自身维度

    Raises:
        ValueError: 校验失败
    """
    main_dimension_ids = []
    for dim_idx, dim in enumerate(dimensions):
        has_links = any(val.linked_value_ids for val in dim.values)
        if has_links:
            main_dimension_ids.append(dim.id)

    if len(main_dimension_ids) > 1:
        raise ValueError(
            f"多个维度使用了 linked_value_ids，只允许一个主维度: "
            f"{', '.join(main_dimension_ids)}"
        )

    # 校验每个链接指向的值存在且不指向自身维度
    for dim_idx, dim in enumerate(dimensions):
        for val in dim.values:
            for linked_id in val.linked_value_ids:
                target_idx, _ = _find_value_by_id(dimensions, linked_id)
                if target_idx == dim_idx:
                    raise ValueError(
                        f"值 '{val.id}' 的 linked_value_ids 指向自身维度 '{dim.id}'"
                    )


# ════════════════════════════════════════════════════════════════
# 笛卡尔积展开（核心算法）
# ════════════════════════════════════════════════════════════════

def expand_combinations(dimensions: list[PipelineDimension]):
    """展开所有维度组合，支持 linked_value_ids 值级引用。

    算法：
      1. 校验全局 linked_value_ids 约束（主维度不冲突）
      2. 正常笛卡尔积展开所有维度
      3. 对每个组合，检测值的 linked_value_ids
      4. 如果有引用 → 覆盖模式替换对应维度的槽位
      5. yield 最终组合

    Args:
        dimensions: 维度定义列表

    Yields:
        tuple[PipelineDimensionValue, ...]: 一个完整组合的维度值元组

    Raises:
        ValueError: linked_value_ids 校验失败
    """
    # ── 全局校验：只有 linked_value_ids 约束 ──
    _validate_linked_value_ids(dimensions)

    # ── 去重集合：用 value id 元组标识已 yield 的组合 ──
    yielded: set[tuple[str, ...]] = set()

    # ── 正常笛卡尔积 ──
    for values_tuple in itertools.product(*[d.values for d in dimensions]):
        # 收集替换映射: {target_dim_index: replacement_value}
        replacements: dict[int, PipelineDimensionValue] = {}
        error = None

        for src_idx, (dim, val) in enumerate(zip(dimensions, values_tuple)):
            for linked_id in val.linked_value_ids:
                try:
                    target_idx, target_val = _find_value_by_id(dimensions, linked_id)
                except ValueError as e:
                    error = str(e)
                    break

                # 检查同一维度的多个链接是否冲突
                if target_idx in replacements:
                    existing = replacements[target_idx]
                    if existing.id != target_val.id:
                        error = (
                            f"linked_value_ids 冲突：维度 '{dimensions[target_idx].id}' "
                            f"已被替换为 '{existing.id}'，不能同时替换为 '{target_val.id}'"
                        )
                        break
                else:
                    replacements[target_idx] = target_val

            if error:
                break

        if error:
            raise ValueError(error)

        # ── 构造最终组合 ──
        if replacements:
            new_values = list(values_tuple)
            for dim_idx, replacement_val in replacements.items():
                new_values[dim_idx] = replacement_val
            result = tuple(new_values)
        else:
            result = values_tuple

        # ── 去重：跳过已 yield 过的组合 ──
        result_ids = tuple(v.id for v in result)
        if result_ids not in yielded:
            yielded.add(result_ids)
            yield result


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
