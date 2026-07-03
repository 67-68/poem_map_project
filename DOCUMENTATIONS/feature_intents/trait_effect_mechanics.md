# poisoned + sprained_ankle 临时负面 Trait

## 文件
- `model/enumerates.gd` — TRAITS 枚举注册
- `data/1_core_rules/traits/_traits.csv` — trait 数据行
- `core/survival_manager.gd` — aggregate_trait_effect() 到期移除
- `core/action_manager.gd` — get_action_day_cost() + check_action_validity() hint
- `ui/action_button.gd` — _on_button_pressed() 额外时间扣除

## poisoned（中毒）

每旬扣除 15 生命值，持续 2 旬后自动移除。

| 属性 | 值 |
|------|-----|
| trait_id | `poisoned` |
| 名称 | 中毒 |
| topic | DISEASE |
| 持续 | 2 旬（hardcoded, lasting_xun >= 2 → remove） |
| trait_effect_operations | `prop_sub(name=health; val=15)` |

### 状态转换

```
获得 poisoned → lasting_xun=0
  ↓ 每旬 aggregate_trait_effect()
lasting_xun += 1 → operate_continuous_effect() → health-15 → 红色染色
  ↓ (poison 在 color_reset 之后执行，染色正确)
lasting_xun >= 2 → remove_trait(poisoned)
```

## sprained_ankle（崴脚）

行动点击时额外消耗 1 时间点，持续 2 旬后自动移除。仅对有时间消耗的主行动生效（子行动无 TimeOperator 故不受影响）。

| 属性 | 值 |
|------|-----|
| trait_id | `sprained_ankle` |
| 名称 | 崴脚 |
| 持续 | 2 旬（hardcoded） |

### 状态转换

```
获得 sprained_ankle → lasting_xun=0
  ↓ 每旬 aggregate_trait_effect()
lasting_xun += 1
  ↓ lasting_xun >= 2 → remove_trait(sprained_ankle)
玩家点击行动（base_cost > 0）→ 额外 append_stat("_time", -1) + advance_time(1)
```

### Hint 格式

- 失败态：`时间剩余3天，但这项行动需要5(4+1, 由于『崴脚』)天`
- 成功态：`时间充足（剩余10天，需要5(4+1, 由于『崴脚』)天）`

## 约束

- 到期移除逻辑目前在 `aggregate_trait_effect()` 中硬编码。未来若 trait 数量增多，应抽象为 Trait 的 `max_duration_xun` 字段，或给 Trait 挂时间 add 的特殊类用钩子处理。
