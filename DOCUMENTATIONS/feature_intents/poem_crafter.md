# 诗词评分创作 — 功能意图

**状态**: 🟢 V13（意象类型匹配 PoemType + 预览效果 + 发布执行 BuffOperator）

---

## 意图摘要（<200字）

线性评分制不变。新增意象类型匹配：`imaginary_type` 计数 sorted multiset → `Database.poem_types` → `PoemType`。预览中展示匹配到的类型名 + 组成 + 发布效果（`BuffOperator.describe_preview()`）。CheckButton「发布」勾选后直接执行 `PoemType.publication_effects`（注入 `source_uuid=poem.uuid` → `BuffOperator.operate()`），并用 `PoemEffectCalculator` 格式化 `effect_desc` 注入事件 ctx。

---

## V13 变更

| 变更项 | 说明 |
|--------|------|
| 🆕 意象类型匹配 | `PoemCraftingCalculator.match_poem_type()` — `imaginary_type` 计数 sorted multiset 匹配 `Database.poem_types` |
| 🆕 预览类型信息 | 精力方向行后插入类型名 + 组成（三项用 " + " 连接）+ 发布效果预览 |
| 🆕 发布执行 BuffOperator | CheckButton 勾选 → `_cached_poem_type.publication_effects` 遍历 → `source_uuid=poem.uuid` → `BuffOperator.operate()` |
| ♻ PoemEffectCalculator 重构 | 参数从 `Poem` 改为 `PoemType`，`calculate()` 内部调用 `get_effects_text()` 格式化 |
| `PoemCraftingResult.matched_poem_type` | 新增字段，`calculate_poem_grade()` 步骤 6 自动填充 |

### 预览行布局 (V13)

| 序号 | 内容 | 颜色 | 来源 |
|------|------|------|------|
| 0 | 配方诗名（命中时） | `#ffd700` | `result.matched_recipe.name` |
| 1 | 意象丰瘠 | `#daa520` | `result.base_level` |
| 2 | 灵感手感 | `#87ceeb` | `result.upgrade_probability` |
| 3 | 精力方向 | white | `current_mode` |
| 🆕 4 | 类型名 + 组成 + 发布效果 | `#ccaa44`/white | `_cached_poem_type` |
| 5 | 代价预览（分隔线+详情） | `#cc6666` | `_cached_cost_operators` |
| 6 | 奖励预览（分隔线+详情） | `#66cc66` | `_cached_mode_reward_operator` |

### mode → 即时激励 (V10, 保留)

| Mode | 即时奖励 | named_amounts |
|:----:|:--------:|:---:|
| `gan_ye` (干谒权贵) | money | `m_money_gain` = 30 |
| `deng_gao` (登高抒怀) | prestige | `m_prestige_gain` = 5 |

## 更改文件

| 文件 | 改动 |
|------|------|
| `core/poem_crafting_calculator.gd` | 🆕 `match_poem_type()` 静态函数; `PoemCraftingResult.matched_poem_type`; `calculate_poem_grade()` 步骤 6 |
| `ui/poem_crafter.gd` | 🆕 `_cached_poem_type` 缓存; `_build_poem_type_preview_lines()`; 预览/提交/刷新行中插入类型信息; 发布改执行 `BuffOperator.operate()` |
| `core/poem_effect_calculator.gd` | ♻ 重构: `calculate(poem_type: PoemType)` → 从 PoemType 格式化 `effect_desc` |
| `core/model/imaginary.gd` | V11: `imaginary_type` + `created_at_day` 字段（无变化） |
| `core/poem_type.gd` | V11: `@tool` + `get_effects_text()`（无变化） |
