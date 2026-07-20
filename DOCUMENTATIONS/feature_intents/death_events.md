# DeathEvent 模块 — 死亡事件系统

## 涉及文件

| 文件 | 角色 |
|------|------|
| [`core/death_events.gd`](core/death_events.gd) | DeathEvent 类定义，继承 RandomEvent |
| [`core/model/game_save_data.gd`](core/model/game_save_data.gd) | 持久化字段: death_reason, death_tutorial |
| [`core/game_state.gd`](core/game_state.gd) | 代理属性: death_reason, death_tutorial |
| [`core/operators/system_operator.gd`](core/operators/system_operator.gd) | game_over 命令，death_hint 为空时兜底读取 GameState |
| [`ui/tomb_stone_screen.gd`](ui/tomb_stone_screen.gd) | 墓碑界面：读取 death_reason + death_tutorial 展示 |
| [`data/4_eras/events/end_random_events/`](data/4_eras/events/end_random_events/) | 死亡事件 .tres 存放目录 |

## 效果描述

当玩家健康值归零（或其他死亡条件满足）时，SurvivalManager 触发生命终结流程，EventManager 从 end_random_events 池中抽选 DeathEvent。墓碑界面展示：

1. **death_reason**（死亡原因）— 红色居中，头部宣判
2. **death_tutorial**（死亡评语）— 灰色斜体居中，总结一生

## 数据流

```
SurvivalManager (health=0)
  → tag: actor:health:death:general
  → EventManager.scan_death_events()
  → 抽选 DeathEvent
  → DeathEvent.on_enter()
       ├── GameState.death_reason = self.death_reason
       └── GameState.death_tutorial = self.death_tutorial
  → 玩家选选项
  → SystemOperator.operate(command="game_over")
       ├── death_hint 非空? 直接用（故事弧 the_end 路径）
       └── death_hint 为空? 从 GameState.death_reason 兜底（DeathEvent 路径）
  → EventBus.show_tombstone_screen.emit(death_hint)
  → main.gd._on_game_over
  → 场景切换 → TombStoneScreen
       ├── 读取 GameState.death_reason → 头部宣判
       ├── 读取 GameState.death_tutorial → 评语区域
       ├── _populate_poems(): 从 PlayerState.created_poems 取诗词
       │     ├── 清空 SubViewport 现有子节点（placeholder label）
       │     ├── 实例化 final_poem_label.tscn（RichTextLabel）
       │     ├── .text = poem.name（poem extends Trait → GameEntity）
       │     ├── 随机 position（约束在 viewport 512×200 边界内）
       │     ├── 随机 self_modulate（RGB 随机 + alpha 0.70~0.95）
       │     └── add_child 到 SubViewport（允许重叠，制造散落混乱感）
       └── PoemAssessment label（poem_accessment，未实现）
```

## DeathEvent .tres 文件格式

参见 [`ui/tomb_stone_screen.tscn`](ui/tomb_stone_screen.tscn) 顶部注释块。

关键字段：
- `script_class = "DeathEvent"`（非 RandomEvent）
- `script = ExtResource("..." path="res://core/death_events.gd")`
- `death_reason` — 死亡原因 i18n key
- `death_tutorial` — 死亡评语 i18n key
- `SystemOperator.death_hint = ""` — 留空，由 DeathEvent.on_enter() 路径兜底

## 兼容性

- 故事弧结局 [`the_end.tres`](data/5_story_arcs/755_backhome/the_end.tres) 保持 `BaseEvent` + `SystemOperator.death_hint` 直接赋值，不受影响
- `GameState.death_cause` 保留不删除，作为 TombStoneScreen 的第三级 fallback
