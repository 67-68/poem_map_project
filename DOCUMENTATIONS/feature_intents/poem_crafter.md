# 诗词评分创作 — 功能意图

**状态**: 🟢 V14（主导元素分类 → PropertyOperator 属性奖励 + BaseOperator 泛化）

---

## 意图摘要（<200字）

线性评分制不变。V14 将 `PoemType.publication_effects` 从 `Array[BuffOperator]` 泛化为 `Array[BaseOperator]`，支持 PropertyOperator（直接属性奖励）。10 种 PoemType 按"主导元素"分类法固化属性奖励到 .tres 数据层：功名主导（≥2 功名）→ +8 望；隐逸主导（≥2 隐逸）→ +8 势；狂放主导（≥2 狂放）→ +10 兴；均衡（各×1）→ 望+5 势+5 兴+6。诗词等级不影响发布奖励。

---

## V14 变更

| 变更项 | 说明 |
|--------|------|
| ♻ 类型泛化 | `PoemType.publication_effects`: `Array[BuffOperator]` → `Array[BaseOperator]` |
| 🆕 主导元素分类 | 10 种 PoemType 按 composition 中某元素 ≥2 即为该元素主导，固化到 .tres |
| 🆕 属性奖励 | 6 个 PropertyOperator .tres: large_wang(8), large_shi(8), large_xing(10), mid_wang(5), mid_shi(5), mid_xing(6) |
| ♻ poem_crafter 执行 | 遍历时 BuffOperator 仍注入 source_uuid → operate()；PropertyOperator 直接 operate() |

### 主导元素 → 属性映射

| 主导元素 | 涉及类型 | PropertyOperator 资源 | 效果 |
|----------|---------|----------------------|------|
| 功名 (≥2) | ggg, ggy, ggk | `poem_pub_large_wang` | 望 +8 |
| 隐逸 (≥2) | gyy, yyy, yyk | `poem_pub_large_shi` | 势 +8 |
| 狂放 (≥2) | gkk, ykk, kkk | `poem_pub_large_xing` | 兴 +10 |
| 均衡 (1+1+1) | gyk | `poem_pub_mid_wang/shi/xing` | 望+5 势+5 兴+6 |

> 主导元素分类法：只要某个元素占了 ≥2 个槽位（AAB/AAC/AAA 都算 A 主导），即体现该元素的极端物理特征；ABC 为系统平衡态。诗词等级（Lv1/2/3）不区分，统一使用 Large/Mid 档位。

---

## V13 变更（已吸纳）

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
| `core/poem_type.gd` | V14: `publication_effects`: `Array[BuffOperator]` → `Array[BaseOperator]` |
| `core/poem_effect_calculator.gd` | V14: 日志版本号更新，类型注释适配 BaseOperator |
| `ui/poem_crafter.gd` | V14: 执行逻辑兼容 BuffOperator + PropertyOperator + 通用 BaseOperator |
| `data/1_core_rules/poem_types/poem_pub_*.tres` | 🆕 6 个 PropertyOperator .tres 资源文件 |
| `data/1_core_rules/poem_types/poem_type_*.tres` | V14: 10 个 PoemType .tres 的 publication_effects 引用 PropertyOperator 资源 |
| `core/poem_crafting_calculator.gd` | 🆕 `match_poem_type()` 静态函数; `PoemCraftingResult.matched_poem_type`; `calculate_poem_grade()` 步骤 6 |
| `core/model/imaginary.gd` | V11: `imaginary_type` + `created_at_day` 字段（无变化） |
