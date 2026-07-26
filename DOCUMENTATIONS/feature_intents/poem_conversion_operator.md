# PoemConversionOperator — 功能意图

**状态**: 🟡 新建

---

## 意图摘要（<200字）

诗词按类型过滤→按 level 产出资源。与 PoemRewardOperator 根本差异：无升级概率（严格按 level 查表）、支持 `type_prefered` 按诗词组成过滤、`poem_lowest_level` 控制整体偏移。

---

## 核心玩法

### Level → Size 偏移

```
effective_index = poem.level + poem_lowest_level - 1
size_key = LEVEL_TO_SIZE_BASE[effective_index]

poem_lowest_level=1: L1→s, L2→m, L3→l  (默认)
poem_lowest_level=2: L1→m, L2→l, L3→xl
```

### type_prefered 过滤

展平 `poem.used_imaginary_types` → sorted Array → 与 `type_prefered` sorted 比较：

- **strict** (`!allow_fuzzy_type`): 数组严格相等
- **fuzzy** (`allow_fuzzy_type`): 仅计数分布相等（keys 可不同，values 必须相同）
- 无匹配时直接 `return`，不回落全量随机

### 完整流程

```
1. operate()
2. type_prefered 非空? → _pick_poem_by_type() → 无匹配? → return
3. type_prefered 为空? → _pick_random_poem() → 无 Poem? → return
4. poem.level → effective_index → size_key
5. size_key in {xxs, xxl}? → 直接查 named_amounts → prop_op.value
6. size_key in {s, m, l, xl}? → ranked_value → PropertyOperator.operate()
7. 消耗诗词: created_poems.remove + remove_trait + Database.traits.erase
8. show_hint
```

---

## 更改文件

| 文件 | 改动 |
|------|------|
| [`core/operators/poem_conversion_operator.gd`](core/operators/poem_conversion_operator.gd) | **新建** — 完整 operator |
| [`data/1_core_rules/translations/_dynamic_events.csv`](data/1_core_rules/translations/_dynamic_events.csv) | **新增** — 7 个翻译 key |
