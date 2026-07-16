# 修饰符属性效果系统 (Modifier Props)

> 📅 创建日期：2026-07-11
> 🔄 更新日期：2026-07-16 — 重写为 BuffOperator 注册表模式（路径 A：统一注册表入口，保持被动阻尼）

## 文件

- [`core/modifier_formula.gd`](core/modifier_formula.gd) — 纯静态工具类，S 型阻尼公式：`amplify()` / `dampen()`
- [`core/modifier_config.gd`](core/modifier_config.gd) — NPC 派系映射表 + 8 条修饰符效果配置表（效果唯一数据源 + UI preview/hint 消费方）
- [`core/modifier_prop_registrar.gd`](core/modifier_prop_registrar.gd) — 🆕 监听 `player_stat_changed`，自动注册/注销到 `active_modifiers`
- [`core/modifier_registry.gd`](core/modifier_registry.gd) — 🆕 统一查询门面：`get_modifier_prop_adjusted_delta()` 从注册表读取并链式应用公式
- [`core/buff_operator.gd`](core/buff_operator.gd) — 理念 Buff 注册器（与 `modifier_prop_effect` 共享 `active_modifiers` 注册表）
- [`core/player_state.gd`](core/player_state.gd) — `_ready()` 调用 `ModifierPropRegistrar.initialize()`；`_apply_modifier_formula()` 委托 `ModifierRegistry`
- [`core/survival_manager.gd`](core/survival_manager.gd) — `_apply_prop_decay()` 每旬势衰减
- [`core/action_manager.gd`](core/action_manager.gd) — `check_archetype_property_costs()` faction-aware 预估
- [`core/hints/operator_preview_formatter.gd`](core/hints/operator_preview_formatter.gd) — Operator 预览中注入 modifier 修正后值
- [`core/poem_crafting_calculator.gd`](core/poem_crafting_calculator.gd) — 才华 S 型阻尼增益诗词评分
- [`core/hints/modifier_hint_formatter.gd`](core/hints/modifier_hint_formatter.gd) — UI 面板的 modifier 效果 BBCode 文本

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

## 新架构数据流（2026-07-16）

```
启动:
  PlayerState._ready()
    → ModifierPropRegistrar.initialize()
      → 遍历 MODIFIER_EFFECTS 中 source_prop∈{astuteness,talent,composure} 的条目
      → 写入 type="modifier_prop_effect" 到 GameSave.data.active_modifiers
      → 连接 player_stat_changed 信号

属性变化:
  PlayerState.append_stat(astuteness, +10)
    → player_stat_changed 信号
    → ModifierPropRegistrar._on_stat_changed("astuteness")
      → _unregister_prop("astuteness") ← 删除 source="modifier_prop:astuteness" 旧条目
      → _sync_prop("astuteness") ← 用新值重新注册

属性修正查询:
  PlayerState.append_stat(prestige, +30)
    → _apply_modifier_formula("prestige", 30)
    → ModifierRegistry.get_modifier_prop_adjusted_delta("prestige", 30)
      → 遍历 active_modifiers 中 type="modifier_prop_effect" 的条目
      → 过滤: target_prop 匹配 / delta_sign 匹配 / faction_filter 运行时懒加载
      → 链式 amplify/dampen
      → 返回修正后 delta

前置预估 (UI 灰化):
  ActionManager.check_archetype_property_costs()
    → ModifierRegistry.get_modifier_prop_adjusted_delta(prop_name, -raw_need)
    → 得到预估修正值 → 与当前值比较

诗词评分:
  PoemCraftingCalculator.calculate_poem_grade()
    → raw score 计算（不变）
    → ModifierFormula.amplify(score, talent_val, 0.4, 35.0)

势衰减:
  SurvivalManager._apply_prop_decay()
    → PlayerState.append_stat(momentum, -5)
    → append_stat 中 ModifierRegistry 自动 dampen（城府越高衰减越少）
```

## 注册表条目结构

`GameSave.data.active_modifiers` 中 `type="modifier_prop_effect"` 的条目：

```gdscript
{
    "source": "modifier_prop:astuteness",   # 来源标识
    "type": "modifier_prop_effect",          # 区分于理念 buff
    "source_prop": "astuteness",
    "target_prop": "momentum",               # "" = 任意属性
    "direction": "dampen",
    "delta_sign": "negative",
    "faction_filter": "",                    # "" | "qingliu" | "zhuoliu"
    "mod_val": 20,                           # 注册时的属性值快照
    "max_limit": 0.8,
    "half_point": 20.0,
    "hint_text": "城府 {mod_val} → 势衰减减免 {pct}%",
}
```

## 与理念 Buff 的关系

理念 Buff（`BuffOperator`）和修饰符属性（`ModifierPropRegistrar`）共享同一个 `active_modifiers` 注册表，通过 `type` 字段区分：

| type | 注册者 | 触发方式 |
|------|--------|---------|
| `efficiency` | BuffOperator | 理念等级提升 |
| `per_xun_passive` | BuffOperator | 理念等级提升 |
| `cap_boost` | BuffOperator | 理念等级提升 |
| `modifier_prop_effect` | ModifierPropRegistrar | 属性值变化自动同步 |

理念退出时 `BuffOperator.on_exit()` 按 `source_uuid` 精确删除；修饰符属性变化时 `ModifierPropRegistrar._sync_prop()` 按 `source = "modifier_prop:{prop}"` 批量替换。两者互不干扰。
