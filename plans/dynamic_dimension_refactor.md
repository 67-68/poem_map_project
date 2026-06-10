# Dynamic Dimension 重构方案

> **状态：** ✅ 已确认，待实施
> **替代文档：** [`plans/dynamic_dimension_architecture.md`](dynamic_dimension_architecture.md)（旧版，将被此文档取代）

---

## 1. 动机

旧版 Dynamic Dimension 系统（`EXTRACTOR_REGISTRY` + `_extract_scene_tags()` + 维度级 `dynamic` 标记）存在以下问题：

1. **过度工程**：全局注册表、context 传递机制、dynamic/static 维度分离算法，只为「场景 tags 分发」一个用例
2. **从未在生产环境跑过**：零个 JSON 配置使用了 `dynamic=True`
3. `SceneValue` 语义标记名存实亡（JSON 反序列化后类型丢失）

需要重构为更简单的双轨机制：**值级引用（linked_value_ids）+ 内联计算（inline computation）**。

---

## 2. 新架构：双轨机制

### 2.1 轨 A：值级引用（linked_value_ids）

一个 `PipelineDimensionValue` 可以声明它「链接」到另一个维度的某个具体值。

```json
{
  "id": "L0",
  "name": "门子/家奴",
  "linked_value_ids": ["TypeA"],
  ...
}
```

语义：**当 L0 被选中时，维度「资源掠夺」固定为 TypeA，不再与其他值自由组合。**

#### 约束

- `linked_value_ids` 指向的值必须来自**不同于当前维度的其他维度**
- 如果指向自身维度 → **报错**
- 多个 `linked_value_ids` 必须指向**同一个目标维度**（如都指向 `TypeA`、`TypeB`，不可同时指向 `TypeA` 和 `M0`）
- 如果多个值指向不同目标维度 → **报错**

### 2.2 轨 B：内联计算（inline computation）

保留 `PipelineDimension.dynamic` 标记（标记为 DEPRECATED 但保持向后兼容）和 `value_extractor_config`。

`expand_combinations()` 内联处理逻辑：

```python
def expand_combinations(dimensions):
    # 1. 正常笛卡尔积展开
    for values_tuple in itertools.product(*[d.values for d in dimensions]):
        # 2. 检测 linked_value_ids → 覆盖模式替换对应维度槽位
        # 3. 如果某维度标记了 dynamic（DEPRECATED）→
        #    从 value_extractor_config 读参数，对当前值做内联计算
        # 4. yield 最终组合
```

不再需要 `EXTRACTOR_REGISTRY` 全局注册表。计算逻辑直接写在 `expand_combinations()` 中。

---

## 3. 数据模型变更

### tools/config.py

```python
# 删除：
class SceneValue(PipelineDimensionValue):  # 整类删除
    pass

# PipelineDimensionValue 修改：
class PipelineDimensionValue(BaseModel):
    id: str = ""
    name: str = ""
    description: str = ""
    scale: float = 1.0
    operator_dsl: str = ""
    tags: list[str] = []                    # ✂️ 删除
    linked_value_ids: list[str] = []        # ✂️ 新增
    narrative_constraint: Optional[NarrativeConstraint] = None

# PipelineDimension 修改：
class PipelineDimension(BaseModel):
    id: str = ""
    name: str = ""
    description: str = ""
    values: list[PipelineDimensionValue] = []
    dynamic: bool = False                   # 保留，标记 DEPRECATED
    value_extractor_key: str = ""           # ✂️ 删除
    value_extractor_config: dict = {}       # 保留（供内联计算读配置）
    blacklist_config: Optional[...] = None  # 不变
```

### tools/event_generator/dimensions.py

```python
# 删除：
EXTRACTOR_REGISTRY            # 全局注册表
register_extractor()          # 注册函数
_extract_scene_tags()         # 场景标签提取器

# 修改：
expand_combinations()         # 增加 linked_value_ids 处理逻辑
```

---

## 4. 展开算法详细流程

```python
def expand_combinations(dimensions: list[PipelineDimension]):
    """
    1. 正常笛卡尔积展开所有维度
    2. 对每个组合检测 linked_value_ids
    3. 如果有 linked_value_ids → 覆盖模式替换对应维度
    """
    for values_tuple in itertools.product(*[d.values for d in dimensions]):
        # 收集所有值的 linked_value_ids
        replacements = {}  # {target_dim_index: replacement_value}
        error = None
        
        for idx, (dim, val) in enumerate(zip(dimensions, values_tuple)):
            for linked_id in val.linked_value_ids:
                # 查找 linked_id 属于哪个维度
                target_dim_idx, target_val = _find_value_by_id(dimensions, linked_id)
                if target_dim_idx == idx:
                    error = f"值 '{val.id}' 的 linked_value_ids 指向自身维度"
                    break
                if target_dim_idx in replacements:
                    # 检查是否指向同一维度
                    if target_dim_idx != list(replacements.keys())[0]:
                        error = "多个 linked_value_ids 指向不同维度"
                        break
                replacements[target_dim_idx] = target_val
        
        if error:
            raise ValueError(error)
        
        # 应用替换
        if replacements:
            new_values = list(values_tuple)
            for dim_idx, replacement_val in replacements.items():
                new_values[dim_idx] = replacement_val
            yield tuple(new_values)
        else:
            yield values_tuple
```

---

## 5. 向后兼容性

| 方面 | 状态 | 说明 |
|------|------|------|
| 旧版 JSON 配置 | ✅ 兼容 | `SceneValue` 会被反序列化为 `PipelineDimensionValue`（Pydantic 宽松模式）；`dynamic` 字段保留但标记废弃 |
| `expand_combinations()` 签名 | ✅ 兼容 | 去掉 `registry` 参数，但旧调用方传参时该参数会被忽略 |
| 旧版单元测试 | ✅ 兼容 | `TestExtractSceneTags` 删除，`TestExpandCombinations` 重写 |
| CSV 输出格式 | ✅ 兼容 | 无变化 |

---

## 6. 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `tools/config.py` | ✅ 修改 | 删 `tags`、`SceneValue`、`value_extractor_key`；加 `linked_value_ids` |
| `tools/event_generator/dimensions.py` | ✅ 修改 | 删注册表 + extractor；重写 `expand_combinations()` |
| `tools/test_generate_orthogonal_events.py` | ✅ 修改 | 删旧测试；加 linked_value_ids 测试 |
| `plans/dynamic_dimension_architecture.md` | ✅ 废弃 | 被本文档取代 |
| `plans/dynamic_dimension_refactor.md` | ✅ 新增 | 本文档 |

---

## 7. 实施顺序

1. **Phase 1**: 数据模型清理（`tools/config.py`）
2. **Phase 2**: 展开算法重写（`tools/event_generator/dimensions.py`）
3. **Phase 3**: 测试重构（`tools/test_generate_orthogonal_events.py`）
4. **Phase 4**: 文档更新
5. **Phase 5**: 验证（运行测试 + dry-run）
