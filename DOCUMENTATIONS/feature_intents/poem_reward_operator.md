# PoemRewardOperator — 功能意图

**状态**: 🟡 新建（V10）

---

## 意图摘要（<200字）

诗词价值不再创作时固化到 Poem 对象上。PoemRewardOperator 接管「消费诗词」逻辑：选择一首 Poem，根据 mode 产出对应资源（money / literary_fame / progress），level 决定档位（small/medium/large），消费时复用作诗时的升级概率公式（L1→L2 48%, L2→L3 48%）。

---

## 核心玩法

### Mode → 产出资源

| Mode | 属性名 | 影响 |
|------|--------|------|
| `money` | `money` | 金钱（15/30/50） |
| `fame` | `literary_fame` | 文学声望（2/5/8） |
| `baiye` | `progress` | 仕途进度（3/6/10） |

### Level → 档位

| Poem.level | 档位 | named_amounts 前缀 |
|:----------:|:----:|:-----------------:|
| 1 (平庸) | small | `s_` |
| 2 (佳作) | medium | `m_` |
| 3 (绝唱) | large | `l_` |

### 消费时升级概率

复用 [`PoemCraftingCalculator.calculate_level_upgrade_probability(level)`](core/poem_crafting_calculator.gd)：

| Poem.level | 段位中位 score | 升级概率 | 升级后 |
|:----------:|:------------:|:----:|:----:|
| 1 | 12 | 48% | L1→L2 |
| 2 | 37 | 48% | L2→L3 |
| 3 | — | 0% | 已是绝唱 |

randf() 掷骰子由 PoemRewardOperator 的 `_on_poem_picked` 执行，不在纯函数中。

### 完整流程

```
1. operate() → 收集所有 Poem traits
2. EventBus.push_picker → 玩家选择（可选留空）
3. 未选 → Logging.warn + return
4. 选中 poem:
   a. 读取 poem.level
   b. calculate_level_upgrade_probability(level) → 获得升级概率
   c. randf() 掷骰子 → 决定 effective_level
   d. effective_level → size (small/medium/large)
   e. mode → property 名称 (money/literary_fame/progress)
   f. 创建 PropertyOperator(ranked_value=size) → named_amounts 自动解析数值
   g. PropertyOperator.operate() → 执行 append_stat
   h. PlayerState.remove_trait(poem.uuid) → 消耗诗词
   i. show_hint 展示收益文本（如 "《佳作》换得中等金钱（灵感迸发！）"）
```

### describe_preview() — Hover 预览文本

[`describe_preview()`](core/operators/poem_reward_operator.gd:143) 为 ActionHintBuilder 提供人类可读预览，三种模式产出不同文本：

| Mode | 预览文本 |
|------|---------|
| `money` | `选择一首诗词换取金钱（平庸→中等 佳作→大量 绝唱→巨额）` |
| `fame` | `选择一首诗词换取文学声望（平庸→少量 佳作→中等 绝唱→大量）` |
| `baiye` | `选择一首诗词换取仕途进度（平庸→少量 佳作→中等 绝唱→大量）` |

> 注意：money 模式升一级（V10.1）：L1→medium, L2→large, L3→extra_large；fame/baiye 使用基础映射（L1→small, L2→medium, L3→large）。

### ActionHintBuilder 集成

PoemRewardOperator 通过两条路径进入 hint 系统：

1. **主路径**：[`build_operator_preview()`](core/action_hint_builder.gd:16) 遍历 action_results/archetype operators，多态调用 `describe_preview()` — PoemRewardOperator 的预览文本直接进入「结果」区
2. **Fallback 路径**：[`_build_archetype_qualitative_preview()`](core/action_hint_builder.gd:86) 当 action_results 为空时从 archetype 生成定性预览，已覆盖 PropertyOperator / TimeOperator / PoemRewardOperator

---

## 与其他模块的关系

### 关联重构：Poem.secular_value/literary_value 删除

V10 同时删除了 [`Poem`](core/model/poem.gd) 和 [`PoemRecord`](core/model/poem_record.gd) 的 `secular_value`/`literary_value` 字段。

诗词创作时不再通过 `MODE_VALUE_MAP` 硬赋值 + PropertyOperator 立即产出收益。收益完全迁移到 PoemRewardOperator。

### 创作 → 消费闭环

```
PoemCrafter._on_button_pressed()
  → Poem.new()（仅 level，无 value）
  → PlayerState.add_trait(poem)（诗词进入库存）

PoemRewardOperator.operate()
  → push_picker（玩家选择诗词）
  → 根据 mode 动态产出资源
  → remove_trait（消耗诗词）
```

---

## 更改文件

| 文件 | 改动 |
|------|------|
| [`core/operators/poem_reward_operator.gd`](core/operators/poem_reward_operator.gd) | **新建** — 完整 operator；V10.2 修正 describe_preview() 等级名称（L1→平庸）并显式 baiye 分支 |
| [`core/action_hint_builder.gd`](core/action_hint_builder.gd) | **修改** — V10.2 `_build_archetype_qualitative_preview()` 新增 PoemRewardOperator 处理分支 |
| [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd) | **修改** — `_calculate_upgrade_probability` → 公开 `calculate_upgrade_probability`；新增 `calculate_level_upgrade_probability(level)`；删除 `MODE_VALUE_MAP` / `PoemCraftingResult.secular_value` / `literary_value` |
| [`core/model/poem.gd`](core/model/poem.gd) | **修改** — 删除 `secular_value` / `literary_value` 字段；简化 `_init` |
| [`core/model/poem_record.gd`](core/model/poem_record.gd) | **修改** — 删除 `secular_value` / `literary_value` 字段 |
| [`ui/poem_crafter.gd`](ui/poem_crafter.gd) | **修改** — 删除 MODE_VALUE_MAP 查表、收益 operators、ctx 中 poem_secular/poem_literary |
| `data/1_core_rules/events/fallback/poem_level_1_fallback.tres` | **修改** — 去掉 {@poem_secular}/{@poem_literary} |
| `data/1_core_rules/events/fallback/poem_level_2_fallback.tres` | **修改** — 去掉 {@poem_secular}/{@poem_literary} |
| `data/1_core_rules/events/fallback/poem_level_3_fallback.tres` | **修改** — 去掉 {@poem_secular}/{@poem_literary} |
| `data/1_core_rules/events/fallback/poem_reveal.tres` | **修改** — 去掉 {@poem_secular}/{@poem_literary} |
