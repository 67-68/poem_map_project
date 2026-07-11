# 修饰符属性效果系统 (Modifier Props)

> 📅 创建日期：2026-07-11

## 文件

- [`core/modifier_formula.gd`](core/modifier_formula.gd) — 纯静态工具类，S 型阻尼公式：`amplify()` / `dampen()`
- [`core/modifier_config.gd`](core/modifier_config.gd) — NPC 派系映射表 + 8 条修饰符效果配置表 + `apply_all_matching_effects()`
- [`core/player_state.gd`](core/player_state.gd:335) — `append_stat()` 中注入 `_apply_modifier_formula()`
- [`core/survival_manager.gd`](core/survival_manager.gd:355) — 新增 `_apply_prop_decay()` 每旬势衰减
- [`core/action_manager.gd`](core/action_manager.gd:291) — `check_archetype_property_costs()` faction-aware 预估
- [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd:101) — 才华 S 型阻尼增益诗词评分
- [`core/action_hint_builder.gd`](core/action_hint_builder.gd:604) — `build_modifier_effects_hint()` UI 展示

## 三条修饰符属性

| 属性 | ENUM | 简称 | 定位 |
|------|------|------|------|
| 城府 | `ASTUTENESS` | 府 | 克制外部消耗，稳中求利 |
| 才华 | `TALENT` | 才 | 放大声望/诗词产出，减免清流成本 |
| 定力 | `COMPOSURE` | 定 | 克制情绪波动和身体损耗 |

## 核心公式

```
amplify:  Result = Raw × (1 + Max_limit × Modifier / (Half_point + Modifier))
dampen:   Result = Raw / (1 + Max_limit × Modifier / (Half_point + Modifier))
```

## 8 条效果

| # | 属性 | 触发条件 | 方向 | 目标 | Max_limit | Half_point |
|---|------|---------|------|------|:---:|:---:|
| 1 | 城府 | delta < 0, prop=momentum | dampen | 势衰减 | 0.8 | 20 |
| 2 | 城府 | delta > 0, prop=prestige | dampen | 声望获取 | 0.5 | 25 |
| 3 | 城府 | delta < 0, NPC=浊流 | dampen | 任意消耗 | 0.5 | 25 |
| 4 | 城府 | delta > 0, prop=money | amplify | 钱财获取 | 0.3 | 30 |
| 5 | 才华 | delta > 0, prop=prestige | amplify | 声望获取 | 0.5 | 25 |
| 6 | 才华 | delta < 0, NPC=清流 | dampen | 任意消耗 | 0.5 | 25 |
| 7 | 定力 | delta > 0, prop=inspiration | dampen | 兴致获取 | 0.5 | 25 |
| 8 | 定力 | delta < 0, prop=health | dampen | 健康失去 | 0.6 | 20 |

## NPC 派系映射

```
清流: libai, gaoshi, wangwei, zhengqian, qingliu
浊流: lilinfu, jiwen, youxiangfu, yangguozhong, guoguofuren, waiqi
中立: hushang（商贩等市井人物）
```

## 数据流

```
属性变动 (Action/Event/Decay)
  → PlayerState.append_stat()
    → buffer_to_prop / buffer_to_region / tier_multiplier（现有）
    → 🆕 _apply_modifier_formula() → ModifierConfig.apply_all_matching_effects()
      → 遍历 8 条效果，逐条匹配 (target_prop, delta_sign, faction_filter)
      → ModifierFormula.amplify() 或 dampen()
      → 返回修正后的 delta
    → hard_max clamp + 写入 GameSave

前置预估 (UI 灰化判断):
  ActionManager.check_archetype_property_costs()
    → ModifierConfig.apply_all_matching_effects(prop_name, -raw_need)
    → 得到 faction-aware 修正后的需求值 → 与当前值比较

诗词评分:
  PoemCraftingCalculator.calculate_poem_grade()
    → raw score 计算（不变）
    → 🆕 ModifierFormula.amplify(score, talent_val, 0.4, 35.0)
    → base_level / upgrade_probability（使用放大后的 score）

势衰减:
  SurvivalManager._apply_prop_decay()
    → PlayerState.append_stat(momentum, -5)
    → append_stat 中的 ModifierFormula 自动 dampen（城府越高衰减越少）
```
