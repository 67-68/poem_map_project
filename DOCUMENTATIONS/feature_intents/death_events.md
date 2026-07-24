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

## 打字机展示流程

TombStoneScreen 从 `_ready()` 开始执行从上到下的逐 label 打字机序列：

```
_hide_all_typewriter_labels()           # 隐藏所有打字机 label + 按钮
title_hbox visible=true                 # 标题行直接显示
history_title_label visible=true        # "观测记录" 直接显示
but_label visible=true                  # 过渡语直接显示

_typewrite_sequence():
  1. Reason           (visible → 逐字打字)
  2. Judgement        (visible → 逐字打字)
  3. TimeActionRank   (visible → 逐字打字)
  4. SpecificResource (visible → 逐字打字)
  5. MidwareProduct   (visible → 逐字打字)
  6. History          (visible → 逐字打字)
  7. SubViewport      (visible → 所有 RichTextLabel 并行 visible_characters Tween)
  8. PoemAssessment   (visible → 逐字打字)
  9. exit_button      (visible → 退出按钮出现)
```

- **Label 打字机**：预填充全文 → `await process_frame` → 锁定 `custom_minimum_size.y` → 清空 → 逐字 `full_text.left(i+1)` + Timer
- **诗词并行**：SubViewport 内所有 `RichTextLabel` 设 `visible_characters=0` → 创建并行 Tween → 同时动画到各自全长
- **速度**：Label 打字 `TYPE_SPEED=0.04` 秒/字，诗词 Tween 总时长 `POEM_TWEEN_DURATION=2.0` 秒
- **无跳过**：玩家必须观看完整打字机序列，不支持点击跳过

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

## 大考结局系统

### 涉及文件

| 文件 | 角色 |
|------|------|
| [`core/exam_ending_router.gd`](core/exam_ending_router.gd) | 静态路由类，优先级匹配 6 条结局路径 |
| [`ui/left_player_panel.gd`](ui/left_player_panel.gd) | AmbitionProgressBar remaining==0 时触发 push_event |
| [`data/4_eras/events/history_events/event_exam_30.tres`] | HistoryEvent: 大考之日到了 |
| [`data/4_eras/events/history_events/event_exam_result.tres`] | BaseEvent: on_enter 调 ExamEndingRouter.evaluate() |
| [`data/4_eras/events/end_random_events/event_ending_*.tres`] | 6 个 DeathEvent 结局文件 |

### 效果描述

野心倒计时归零时触发大考事件链：显示 cinematic 过场（「无人中第」）→ ExamEndingRouter 按优先级评估玩家属性 → 推入对应结局 DeathEvent → 墓碑界面。

### 结局优先级

1. 望 ≥ 100 且 created_poems 中存在 level==3 的诗词 → hidden
2. 势 ≥ 100 → good
3. 望 ≥ 100 → medium
4. 兴 ≥ 100 → bad
5. 钱 ≥ 1000 且势望兴均 < 50 → rich
6. fallback → default

### 数据流

```
left_player_panel._update_ambition_deadline_bar()
  → remaining==0 + !flag_exam_triggered
  → PlayerState.set_flag("flag_exam_triggered", true)
  → EventBus.push_event("event_exam_30")
  → HistoryEvent.on_enter → choice_result:
       PlayTransitionOperator (cinematic: "榜单一空...")
       PushEventOperator ("event_exam_result")
  → BaseEvent event_exam_result.on_enter:
       ExamEndingRouter.evaluate()
         → 优先级匹配属性阈值
         → EventBus.push_event(匹配的 ending DeathEvent)
  → DeathEvent.on_enter → 注入 death_reason/death_tutorial
  → SystemOperator("game_over") → tombstone
```

### 结局内容

| 结局 | 翻译键前缀 | name | death_reason | death_tutorial |
|------|----------|------|-------------|---------------|
| hidden | `ENDING_HIDDEN` | 名满天下 | 名望动天下。虽然没有当上官，但出名了，不日可以类似李白凭借名望接近玄宗。 | 你还记得刚开始的那个玩具吗？虽然出名了但总得带点什么给孩子。 |
| good | `ENDING_GOOD_MOMENTUM` | 一时势盛 | 在一时势盛，但在历史上的地位是被史书寥寥几笔带过的小人物。 | 势属性代表你在官场和浊流中的影响力。 |
| medium | `ENDING_MEDIUM_PRESTIGE` | 清望之士 | 名望动天下，还是被史书带过的小人物，但这次是作为有清望的文坛先辈。 | 如果你能有实际上的诗词创作就好了…… |
| bad | `ENDING_BAD_INSPIRATION` | 逃入诗酒 | 史书会记载你的性情，但你充其量就是小李白的地位。 | 兴需要花费在诗词创作上，才能转化为望。空有兴致而不写诗，终究只是逃避。 |
| rich | `ENDING_RICH` | 富家翁 | 一时巨富，籍籍无名。安史乱起，家财尽被劫掠。 | 流动的财富才是财富。没有权势守护，再多的钱也只是替别人攒的。 |
| default | `ENDING_DEFAULT` | 无疾而终 | 终其一生，不过是个被自己愤慨撕扯的小人物。对自身的自信与自卑交织，在安史之乱前愤懑而终。 | 什么都没做成，什么都没留下。 |

> 📝 所有翻译键（`NAME`, `DESC`, `REASON`, `TUTORIAL` + `EXAM_30_NAME/DESC/OPTION_0`）均存储于 [`_dynamic_events.csv`](data/1_core_rules/translations/_dynamic_events.csv)。

## 隐藏结局继续游戏（"继续游戏"流）

### 触发条件

DeathEvent `event_ending_hidden`（`death_reason="ENDING_HIDDEN_REASON"`）被触发时，墓碑界面在打字机序列结束后显示「继续游戏」按钮。

### 涉及文件

| 文件 | 角色 |
|------|------|
| [`core/game_state.gd`](core/game_state.gd) | 瞬态信号 `pending_hidden_ending_continue: bool` |
| [`ui/tomb_stone_screen.gd`](ui/tomb_stone_screen.gd) | `_is_hidden_ending()` 检测 + `_on_continue_pressed()` 处理器 |
| [`ui/tomb_stone_screen.tscn`](ui/tomb_stone_screen.tscn) | ContinueButton（已有节点，新连信号） |
| [`main.gd`](main.gd) | `_check_hidden_ending_continue()` + `_start_hidden_ending_continue()` |
| [`core/operators/queue_event_operator.gd`](core/operators/queue_event_operator.gd) | 排队 `event_get_official` |
| [`data/5_story_arcs/755_backhome/event_get_official.tres`](data/5_story_arcs/755_backhome/event_get_official.tres) | 被排队的目标事件 |

### 效果描述

隐藏结局（望≥100 + Lv3诗词）不走单向死亡路线。墓碑展示结束后，玩家可以选择「继续游戏」：
1. 解除游戏结束锁 (`is_game_over=false`)
2. 恢复时间流逝 (`TimeService.resume_world()`)
3. 设置时代为 `755_backhome`，时间跳到 755/10/1
4. 初始属性：钱 150，健康 100
5. 播放 cinematic 过场（叙说俗物花光、官场失意、养家糊口）
6. 过场结束后排队 `event_get_official` 进入正常游戏循环

### 数据流

```
TombStoneScreen._typewrite_sequence() 结束
  → _is_hidden_ending()? death_reason=="ENDING_HIDDEN_REASON"
    ├── true  → ContinueButton.visible=true
    └── false → exit_button.visible=true（现有行为）

ContinueButton.pressed:
  → _on_continue_pressed()
    ├── GameState.pending_hidden_ending_continue = true
    ├── GameState.is_game_over = false
    ├── TimeService.resume_world()
    ├── GameState.current_era = "755_backhome"
    ├── TimeService.jump_to(755.75)  // 755年10月1日
    ├── PlayerState.force_set_stat_val("money", 150)
    ├── PlayerState.force_set_stat_val("health", 100)
    └── change_scene_to_file("res://main.tscn")

main.gd._ready():
  → call_deferred("_check_hidden_ending_continue")

_check_hidden_ending_continue():
  → pending_hidden_ending_continue? false → 正常启动，done
  → true:
    ├── pending = false（消耗 flag）
    ├── await 2 × process_frame（等 CinematicOverlay ready）
    └── _start_hidden_ending_continue()

_start_hidden_ending_continue():
  → EventBus.cinematic_start.emit(["俗物花光了…", "官场失意…", "养家糊口…", "……"])
  → CinematicOverlay.finished 信号 → _on_hidden_ending_cinematic_finished()

_on_hidden_ending_cinematic_finished():
  → QueueEventOperator("event_get_official").operate()
  → EventBus.request_event_key.emit("event_get_official", {})
```

## 回家结局系统（755_backhome era）

### 涉及文件

| 文件 | 角色 |
|------|------|
| [`core/exam_ending_router.gd`](core/exam_ending_router.gd) | `evaluate_backhome()` 静态方法：拨浪鼓分叉路由 |
| [`core/operators/backhome_ending_router_operator.gd`](core/operators/backhome_ending_router_operator.gd) | Operator，在路由事件的 choice_result 中调用 `evaluate_backhome()` |
| [`core/survival_manager.gd`](core/survival_manager.gd) | `death_judgement()`: era 755 + 三次濒死耗尽 → push `event_backhome_ending_death` |
| [`data/5_story_arcs/755_backhome/event_backhome_ending_router.tres`](data/5_story_arcs/755_backhome/event_backhome_ending_router.tres) | 路由事件：叙事「小木屋门口」+ 单选项「推门而入」 |
| [`data/5_story_arcs/755_backhome/fengxian_village_entrance_revisit.tres`](data/5_story_arcs/755_backhome/fengxian_village_entrance_revisit.tres) | push 目标从 `backhome_the_wood` 改为 `event_backhome_ending_router` |
| [`data/4_eras/events/end_random_events/event_backhome_ending_good.tres`](data/4_eras/events/end_random_events/event_backhome_ending_good.tres) | DeathEvent: 好结局「风雪归人」 |
| [`data/4_eras/events/end_random_events/event_backhome_ending_death.tres`](data/4_eras/events/end_random_events/event_backhome_ending_death.tres) | DeathEvent: 死亡结局「冻毙于风雪」 |

### 效果描述

755_backhome 时代有三条结局路径，分两个触发入口：

**入口 A — 路途中死亡（SurvivalManager）：**
- 三次濒死兜底耗尽后（`near_death_count >= 3`），不走通用 `scan_death_events()` 随机池
- 直接 push 专属 DeathEvent `event_backhome_ending_death`（冻毙于风雪）
- 玩家在路途中死亡，永远没能到家

**入口 B — 活着到家（到家门口路由）：**
- `fengxian_village_entrance_revisit` 的「走向小木屋」选项 push `event_backhome_ending_router`
- 路由事件展示叙事「你终于走到了小木屋的门口…」+ 单选项「推门而入」
- 点击后 `BackhomeEndingRouterOperator` 调用 `ExamEndingRouter.evaluate_backhome()`
- **唯一分叉条件：`PlayerState.has_trait("rattle_drum")`**
  - 有拨浪鼓 → 历史线：走现有链 `backhome_the_wood` → `backhome_inside_the_wood` → `the_end`（儿子饿死）
  - 无拨浪鼓 → 好结局：push `event_backhome_ending_good`（风雪归人，儿子活着）

| 结局 | 触发条件 | name | death_reason | death_tutorial |
|------|---------|------|-------------|---------------|
| 冻毙于风雪 | health=0 三次濒死耗尽 | ENDING_BACKHOME_DEATH_NAME | 朔风如刀，白雪覆身，没能走完二百四十三里路 | 至少不再痛苦。但妻儿还在等，理想埋在了大唐最冷的冬天 |
| 冻毙于风雪 | health=0 三次濒死耗尽 | ENDING_BACKHOME_DEATH_NAME | 朔风如刀，白雪覆身 | 理想埋在了大唐最冷的冬天 |
| 风雪归人 | 到家 + 无拨浪鼓 | ENDING_BACKHOME_GOOD_NAME | 推开破门，孩子还活着 | 没有功名，但今夜还在一起 |
| 乱世诗人 | 到家 + 有拨浪鼓 + 未目睹冻死骨 | ENDING_BACKHOME_MIDDLE_NAME | 儿子死了，写了一首长诗 | 差一点就成了杜甫，差了一口气 |
| 文章憎命达 | 到家 + 有拨浪鼓 + 目睹冻死骨 | ENDING_BACKHOME_HISTORICAL_NAME | 灶台冰冷，儿子已死 | 诗越伟大，命越凄惨 |

### 数据流

```
入口 A (死亡):
  SurvivalManager.death_judgement()
    → era=="755_backhome" + near_death_count>=3
    → EventBus.request_event_key("event_backhome_ending_death")
    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone

入口 B (到家 — 三层分叉):
  fengxian_village_entrance_revisit → push event_backhome_ending_router
    → on_enter: 叙事展示
    → choice_result: BackhomeEndingRouterOperator.operate()
      → ExamEndingRouter.evaluate_backhome()
        → has_trait("rattle_drum")?
          ├─ NO  → event_backhome_ending_good → tombstone
          └─ YES → flag_witnessed_lishan_corpses?
                    ├─ YES → backhome_the_wood → inside_the_wood → the_end → tombstone
                    └─ NO  → event_backhome_ending_middle → tombstone
```

| 结局 | 触发条件 | name | death_reason | death_tutorial |
|------|---------|------|-------------|---------------|
| 冻毙于风雪 | health=0 三次濒死耗尽 | ENDING_BACKHOME_DEATH_NAME | 朔风如刀，白雪覆身，没能走完二百四十三里路 | 至少不再痛苦。但妻儿还在等，理想埋在了大唐最冷的冬天 |
| 风雪归人 | 到家 + 无拨浪鼓 | ENDING_BACKHOME_GOOD_NAME | 推开破门，孩子还活着，掏出半块胡饼，一家人围坐 | 没有功名没有诗篇，但今夜还在一起。文章憎命达 |
| 历史线 | 到家 + 有拨浪鼓 | （不改动现有内容） | （现有 the_end） | （现有 the_end） |

### 数据流

```
入口 A (死亡):
  SurvivalManager.death_judgement()
    → era=="755_backhome" + near_death_count>=3
    → EventBus.request_event_key("event_backhome_ending_death")
    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone

入口 B (到家):
  fengxian_village_entrance_revisit → push event_backhome_ending_router
    → on_enter: 叙事展示
    → choice_result: BackhomeEndingRouterOperator.operate()
      → ExamEndingRouter.evaluate_backhome()
        → has_trait("rattle_drum")?
          ├─ YES → request_event_key("backhome_the_wood")
          │         → inside_the_wood → the_end → tombstone
          └─ NO  → request_event_key("event_backhome_ending_good")
                    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone
```
  fengxian_village_entrance_revisit → push event_backhome_ending_router
    → on_enter: 叙事展示
    → choice_result: BackhomeEndingRouterOperator.operate()
      → ExamEndingRouter.evaluate_backhome()
        → has_trait("rattle_drum")?
          ├─ YES → request_event_key("backhome_the_wood")
          │         → inside_the_wood → the_end → tombstone
          └─ NO  → request_event_key("event_backhome_ending_good")
                    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone
```

| 结局 | 触发条件 | name | death_reason | death_tutorial |
|------|---------|------|-------------|---------------|
| 冻毙于风雪 | health=0 三次濒死耗尽 | ENDING_BACKHOME_DEATH_NAME | 朔风如刀，白雪覆身，没能走完二百四十三里路 | 至少不再痛苦。但妻儿还在等，理想埋在了大唐最冷的冬天 |
| 风雪归人 | 到家 + 无拨浪鼓 | ENDING_BACKHOME_GOOD_NAME | 推开破门，孩子还活着，掏出半块胡饼，一家人围坐 | 没有功名没有诗篇，但今夜还在一起。文章憎命达 |
| 历史线 | 到家 + 有拨浪鼓 | （不改动现有内容） | （现有 the_end） | （现有 the_end） |

### 数据流

```
入口 A (死亡):
  SurvivalManager.death_judgement()
    → era=="755_backhome" + near_death_count>=3
    → EventBus.request_event_key("event_backhome_ending_death")
    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone

入口 B (到家):
  fengxian_village_entrance_revisit → push event_backhome_ending_router
    → on_enter: 叙事展示
    → choice_result: BackhomeEndingRouterOperator.operate()
      → ExamEndingRouter.evaluate_backhome()
        → has_trait("rattle_drum")?
          ├─ YES → request_event_key("backhome_the_wood")
          │         → inside_the_wood → the_end → tombstone
          └─ NO  → request_event_key("event_backhome_ending_good")
                    → DeathEvent.on_enter → SystemOperator("game_over") → tombstone
```
