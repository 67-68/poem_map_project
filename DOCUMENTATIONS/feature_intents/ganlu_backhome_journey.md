# 赶路回家 — 地点切换 (Ganlu Journey Locations)

## 涉及文件

| 文件 | 改动 |
|------|------|
| [`core/operators/set_stay_place_operator.gd`](core/operators/set_stay_place_operator.gd) | PLACE_CN_MAP 新增 5 个地点映射 |
| [`core/plot_controller.gd`](core/plot_controller.gd) | 新增 progress 阈值监控：>30 push lishan_1, >60 push indifferent_wind_1 |
| [`data/4_eras/755_backhome/gan_lu.tres`](data/4_eras/755_backhome/gan_lu.tres) | 配置 archetype_uuid="gan_lu"，possibility=l_success_rate（100%必中） |
| [`data/1_core_rules/archetypes/ganlu_cost.tres`](data/1_core_rules/archetypes/ganlu_cost.tres) | cost archetype: health -13（使用 named_amount ganlu_health_cost） |
| [`data/1_core_rules/archetypes/ganlu_success.tres`](data/1_core_rules/archetypes/ganlu_success.tres) | success archetype: progress +20（使用 named_amount xl_progress_gain） |
| [`tools/data/named_amounts.json`](tools/data/named_amounts.json) | 新增 ganlu_health_cost: -13, xl_progress_gain: 20 |
| [`data/5_story_arcs/755_backhome/event_backhome_start.tres`](data/5_story_arcs/755_backhome/event_backhome_start.tres) | on_enter_result → dongmen_baqiao |
| [`data/5_story_arcs/755_backhome/backhome_outside_city_1.tres`](data/5_story_arcs/755_backhome/backhome_outside_city_1.tres) | 所有选项 health -13，移除了 progress 自增 |
| [`data/5_story_arcs/755_backhome/backhome_lishan_1.tres`](data/5_story_arcs/755_backhome/backhome_lishan_1.tres) | on_enter → lishan，所有选项 health -13，移除了 progress 自增 |
| [`data/5_story_arcs/755_backhome/backhome_indifferent_wind_1.tres`](data/5_story_arcs/755_backhome/backhome_indifferent_wind_1.tres) | on_enter → frozen_wei_river，所有选项 health -13，移除了 progress 自增 |
| [`data/5_story_arcs/755_backhome/fengxian_village_entrance.tres`](data/5_story_arcs/755_backhome/fengxian_village_entrance.tres) | on_enter_result → fengxian_village |
| [`data/5_story_arcs/755_backhome/fengxian_familiar_path.tres`](data/5_story_arcs/755_backhome/fengxian_familiar_path.tres) | on_enter_result → wooden_hut_door |

## 效果

玩家在 755_backhome 时代执行「赶路」（gan_lu）行动后，每次点击消耗 13 生命并获得 20 进度。PlotController 在每旬 tick 时检查 progress 值：
- progress > 30 → 自动 push 骊山事件
- progress > 60 → 自动 push 结冰渭河事件

此外，`PlayerState.stay_place` 在各事件 on_enter 时自动切换，反映杜甫从长安到奉先的归家行程。

## 进度推进的唯一来源

**所有 progress 累积仅通过 gan_lu 行动的 success archetype (+20) 实现。** 各事件的选项不再独立增加 progress。

## 五个地点

| 序号 | stay_place 值 | 中文名 | 触发事件 | 触发条件 |
|------|--------------|--------|---------|---------|
| 1 | `dongmen_baqiao` | 东门灞桥 | event_backhome_start | gan_lu 事件扫描 |
| 2 | `lishan` | 骊山 | backhome_lishan_1 | progress > 30（PlotController） |
| 3 | `frozen_wei_river` | 结冰渭河上 | backhome_indifferent_wind_1 | progress > 60（PlotController） |
| 4 | `fengxian_village` | 奉先村 | fengxian_village_entrance | （后续事件链） |
| 5 | `wooden_hut_door` | 小木屋门口 | fengxian_familiar_path | （后续事件链） |

## 状态转换

```
gan_lu 点击          → cost: health -13, success: progress +20
进入 event_backhome_start       → stay_place = dongmen_baqiao
PlotController: progress > 30   → push backhome_lishan_1
进入 backhome_lishan_1          → stay_place = lishan
PlotController: progress > 60   → push backhome_indifferent_wind_1
进入 backhome_indifferent_wind_1 → stay_place = frozen_wei_river
进入 fengxian_village_entrance  → stay_place = fengxian_village
进入 fengxian_familiar_path     → stay_place = wooden_hut_door
```

## 防重复机制

- `plot_lishan_triggered`: progress > 30 触发骊山事件后设置，防止同一局重复触发
- `plot_indifferent_wind_triggered`: progress > 60 触发结冰渭河事件后设置，防止同一局重复触发
- 两个 flag 均为 PlayerState 持久化标记，读档不会重复触发

## Era 开关

- **745_ambition**: `rejected_actions=[6]` → gan_lu（赶路）不出现在面板
- **755_backhome**: `accepted_actions=[6]` → gan_lu 唯一可用行动

## 数值一览

| 操作 | 数值 | named_amount |
|------|------|-------------|
| 赶路 cost（生命消耗） | -13 | `ganlu_health_cost` |
| 赶路 success（进度获得） | +20 | `xl_progress_gain` |
| 事件选项（生命消耗） | -13（每个选项） | raw value（-13） |
