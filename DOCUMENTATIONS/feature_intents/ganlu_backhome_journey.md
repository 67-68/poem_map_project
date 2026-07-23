# 赶路回家 — 地点切换 (Ganlu Journey Locations)

## 涉及文件

| 文件 | 改动 |
|------|------|
| [`core/operators/set_stay_place_operator.gd`](core/operators/set_stay_place_operator.gd) | PLACE_CN_MAP 新增 5 个地点映射 |
| [`data/5_story_arcs/755_backhome/event_backhome_start.tres`](data/5_story_arcs/755_backhome/event_backhome_start.tres) | on_enter_result → dongmen_baqiao |
| [`data/5_story_arcs/755_backhome/backhome_lishan_1.tres`](data/5_story_arcs/755_backhome/backhome_lishan_1.tres) | on_enter_result → lishan |
| [`data/5_story_arcs/755_backhome/backhome_indifferent_wind_1.tres`](data/5_story_arcs/755_backhome/backhome_indifferent_wind_1.tres) | on_enter_result → frozen_wei_river |
| [`data/5_story_arcs/755_backhome/fengxian_village_entrance.tres`](data/5_story_arcs/755_backhome/fengxian_village_entrance.tres) | on_enter_result → fengxian_village |
| [`data/5_story_arcs/755_backhome/fengxian_familiar_path.tres`](data/5_story_arcs/755_backhome/fengxian_familiar_path.tres) | on_enter_result → wooden_hut_door |

## 效果

玩家在 755_backhome 时代执行「赶路」（gan_lu）行动后，沿着事件链推进时，`PlayerState.stay_place` 自动依次切换，反映杜甫从长安到奉先的归家行程。

## 五个地点

| 序号 | stay_place 值 | 中文名 | 触发事件 |
|------|--------------|--------|---------|
| 1 | `dongmen_baqiao` | 东门灞桥 | event_backhome_start |
| 2 | `lishan` | 骊山 | backhome_lishan_1 |
| 3 | `frozen_wei_river` | 结冰渭河上 | backhome_indifferent_wind_1 |
| 4 | `fengxian_village` | 奉先村 | fengxian_village_entrance |
| 5 | `wooden_hut_door` | 小木屋门口 | fengxian_familiar_path |

## 状态转换

```
进入 event_backhome_start       → stay_place = dongmen_baqiao
进入 backhome_lishan_1          → stay_place = lishan
进入 backhome_indifferent_wind_1 → stay_place = frozen_wei_river
进入 fengxian_village_entrance  → stay_place = fengxian_village
进入 fengxian_familiar_path     → stay_place = wooden_hut_door
```

## Era 开关

- **745_ambition**: `rejected_actions=[6]` → gan_lu（赶路）不出现在面板
- **755_backhome**: `accepted_actions=[6]` → gan_lu 唯一可用行动

不需要额外 Controller，Era 层已处理。
