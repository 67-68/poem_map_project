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

def _group_linked_by_target(
    dimensions: list[PipelineDimension],
    values_tuple: tuple[PipelineDimensionValue, ...],
) -> list[dict[int, PipelineDimensionValue]]:
    """将 values_tuple 中所有值的 linked_value_ids 按目标维度分组，
    生成替换方案列表（支持叉积：同一目标维度的多个不同值 → 多方案）。

    算法:
      1. 遍历每个维度值，收集 linked_value_ids
      2. 按目标维度索引分组
      3. 如果某目标维度有多于一个唯一值 → 叉积展开
      4. 返回所有可能的替换方案

    Returns:
        list[dict[int, PipelineDimensionValue]]: 替换方案列表。
        每个 dict 是 {target_dim_index: replacement_value}。
        如果没有任何 linked_value_ids，返回 [{}]（一个空替换方案）。

    Raises:
        ValueError: linked_value_ids 指向不存在或自身维度的值
    """
    # ── 第一步：收集所有替换候选，按目标维度分组 ──
    # target_groups: dict[target_dim_idx, list[PipelineDimensionValue]]
    target_groups: dict[int, list[PipelineDimensionValue]] = {}

    for src_idx, (dim, val) in enumerate(zip(dimensions, values_tuple)):
        for linked_id in val.linked_value_ids:
            target_idx, target_val = _find_value_by_id(dimensions, linked_id)
            if target_idx not in target_groups:
                target_groups[target_idx] = []
            target_groups[target_idx].append(target_val)

    if not target_groups:
        return [{}]

    # ── 第二步：对每个目标维度去重，提取唯一值列表 ──
    # unique_options: list[list[PipelineDimensionValue]]
    # 每个子列表对应一个目标维度的所有可能替换值
    unique_options: list[list[PipelineDimensionValue]] = []
    target_dim_indices: list[int] = []

    for target_idx, vals in target_groups.items():
        # 保持顺序去重
        seen: set[str] = set()
        uniq: list[PipelineDimensionValue] = []
        for v in vals:
            if v.id not in seen:
                seen.add(v.id)
                uniq.append(v)
        unique_options.append(uniq)
        target_dim_indices.append(target_idx)

    # ── 第三步：叉积展开 ──
    # 对每个目标维度，从唯一值列表中选一个，组合成替换方案
    schemes: list[dict[int, PipelineDimensionValue]] = []
    for selection in itertools.product(*unique_options):
        scheme: dict[int, PipelineDimensionValue] = {}
        for target_idx, chosen_val in zip(target_dim_indices, selection):
            scheme[target_idx] = chosen_val
        schemes.append(scheme)

    return schemes


def expand_combinations(dimensions: list[PipelineDimension]):
    """展开所有维度组合，支持 linked_value_ids（替换语义）和
    virtual_dimension_ids（虚拟追加语义）双轨并行。

    双轨语义：
      - linked_value_ids（替换）：当值被选中时，引用的维度值替换目标维度槽位。
        约束：单一主维度，所有 link 指向同一 target 维度。
      - virtual_dimension_ids（虚拟追加）：每个 inner list 成为一个独立的
        虚拟维度，与所有原始维度做笛卡尔积，追加到 tuple 末尾。
        无约束：多值可同时触发，不替换任何现有维度。
      - 两轨可共存：一个维度值可同时拥有 linked_value_ids 和 virtual_dimension_ids。

    算法：
      1. 校验全局 linked_value_ids 约束
      2. 分离主维度（基础笛卡尔积）和纯虚拟维度（仅服务于 virtual_dimension_ids）
      3. 基础维度做笛卡尔积 → 应用 linked_value_ids 替换 → 应用 virtual_dimension_ids 追加
      4. yield 所有最终组合（含去重）

    典型用例：
      scene_dailou.linked_value_ids = ["imagery_jade_step"]
        + virtual_dimension_ids = [["identity_qingliu_owner", "identity_qingliu_official"]]
      → 生成 2 个事件：
        (scene_dailou, imagery_jade_step, identity_qingliu_owner)
        (scene_dailou, imagery_jade_step, identity_qingliu_official)

    Args:
        dimensions: 维度定义列表（可能含注入的外部维度如 social_identity）

    Yields:
        tuple[PipelineDimensionValue, ...]: 一个完整组合的维度值元组
        （可能比 dimensions 更长，多出的尾部为虚拟维度值）

    Raises:
        ValueError: linked_value_ids 校验失败
    """
    # ── 全局校验 ──
    _validate_linked_value_ids(dimensions)

    # ── 分离虚拟维度：dimension 中所有值仅通过 virtual_dimension_ids 被引用
    #    （不在基础笛卡尔积中）的维度 ──
    virtual_only_dim_ids: set[str] = _find_virtual_only_dimensions(dimensions)

    base_dimensions = [d for d in dimensions if d.id not in virtual_only_dim_ids]
    # 虚拟维度 map（按 id 快速查找）
    virtual_dim_map: dict[str, PipelineDimension] = {
        d.id: d for d in dimensions if d.id in virtual_only_dim_ids
    }

    # ── 去重集合：用 value id 元组标识已 yield 的组合 ──
    yielded: set[tuple[str, ...]] = set()

    # ── 基础维度笛卡尔积 ──
    if not base_dimensions:
        return

    for values_tuple in itertools.product(*[d.values for d in base_dimensions]):
        # Step 1: 计算 linked_value_ids 替换方案
        schemes = _group_linked_by_target(dimensions, values_tuple)

        for replacements in schemes:
            # 应用替换
            if replacements:
                new_values = list(values_tuple)
                for dim_idx, replacement_val in replacements.items():
                    new_values[dim_idx] = replacement_val
                base_tuple = tuple(new_values)
            else:
                base_tuple = values_tuple

            # Step 2: 收集 virtual_dimension_ids → 虚拟维度组
            virtual_groups: list[tuple[PipelineDimensionValue, ...]] = []
            for val in base_tuple:
                if val.virtual_dimension_ids:
                    for inner_list in val.virtual_dimension_ids:
                        virtual_values: list[PipelineDimensionValue] = []
                        for vid in inner_list:
                            _, v = _find_value_by_id(dimensions, vid)
                            virtual_values.append(v)
                        if virtual_values:
                            virtual_groups.append(tuple(virtual_values))

            if not virtual_groups:
                result = base_tuple
                result_ids = tuple(v.id for v in result)
                if result_ids not in yielded:
                    yielded.add(result_ids)
                    yield result
            else:
                # 虚拟维度组叉积展开，追加到 base_tuple 末尾
                for virtual_combo in itertools.product(*virtual_groups):
                    result = base_tuple + virtual_combo
                    result_ids = tuple(v.id for v in result)
                    if result_ids not in yielded:
                        yielded.add(result_ids)
                        yield result


def _find_virtual_only_dimensions(
    dimensions: list[PipelineDimension],
) -> set[str]:
    """找出仅通过 virtual_dimension_ids 被引用的维度（不出现在基础笛卡尔积中）。

    如果一个维度的所有值都不在 base_dimensions 的正常笛卡尔积中，
    而是仅被其他维度的 virtual_dimension_ids 引用，则该维度 ID 属于此集合。

    判断逻辑：遍历所有维度值，收集 linked_value_ids 指向的值所属的维度；
    任何不在 linked_value_ids 指向范围且不在 base dimensions 显式列表中的
    维度被视为虚拟专用维度。

    实际实现：收集所有 virtual_dimension_ids 内层 ID 所属的维度，
    这些维度如果没有值的 linked_value_ids 指向它们，就是虚拟专用维度。
    """
    # 收集所有 linked_value_ids 指向的维度
    linked_target_dims: set[str] = set()
    for dim in dimensions:
        for val in dim.values:
            for linked_id in val.linked_value_ids:
                try:
                    target_idx, _ = _find_value_by_id(dimensions, linked_id)
                    linked_target_dims.add(dimensions[target_idx].id)
                except ValueError:
                    pass

    # 收集所有 virtual_dimension_ids 内层 ID 所属的维度
    virtual_ref_dims: set[str] = set()
    for dim in dimensions:
        for val in dim.values:
            for inner_list in val.virtual_dimension_ids:
                for vid in inner_list:
                    try:
                        target_idx, _ = _find_value_by_id(dimensions, vid)
                        virtual_ref_dims.add(dimensions[target_idx].id)
                    except ValueError:
                        pass

    # 虚拟专用维度 = 被 virtual 引用但未被 linked 引用的维度
    return virtual_ref_dims - linked_target_dims


# ════════════════════════════════════════════════════════════════
# DimensionCombo 组装
# ════════════════════════════════════════════════════════════════

def _make_combos(
    dimensions: list[PipelineDimension],
    values: tuple[PipelineDimensionValue, ...],
) -> list[DimensionCombo]:
    """将维度定义列表和对应的值元组组装为 DimensionCombo 列表。

    支持变长 values_tuple：当 values 比 dimensions 长时（虚拟维度追加语义），
    多出的尾部值通过 _find_value_by_id 查找所属维度来匹配。
    """
    combos: list[DimensionCombo] = []

    # 前 len(dimensions) 个值按顺序匹配
    for dim, val in zip(dimensions, values):
        combos.append(DimensionCombo(dimension=dim, value=val))

    # 尾部多余的值（来自 virtual_dimension_ids 追加）按值 ID 查找所属维度
    for val in values[len(dimensions):]:
        try:
            dim_idx, _ = _find_value_by_id(dimensions, val.id)
            combos.append(DimensionCombo(dimension=dimensions[dim_idx], value=val))
        except ValueError:
            # 如果找不到所属维度，创建一个最小化的合成维度
            synthetic_dim = PipelineDimension(
                id=val.id,
                name=val.name,
                description="",
                values=[],
            )
            combos.append(DimensionCombo(dimension=synthetic_dim, value=val))

    return combos
