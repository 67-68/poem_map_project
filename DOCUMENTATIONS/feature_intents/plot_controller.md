# PlotController — 主线剧情控制器

## 涉及文件

- `core/plot_controller.gd` — Autoload，监听 xun_tick 并根据 event_counter/progress 触发剧情事件
- `core/model/game_save_data.gd` — 新增 `event_counter: int` 字段（含序列化/反序列化）
- `core/game_state.gd` — 新增 `event_counter` 属性代理到 `GameSave.data.event_counter`
- `characters/narrative_overlay.gd` — `_on_event_ready_to_play()` 开头递增 `GameState.event_counter`
- `data/1_core_rules/plot/plot_prompt_user_action.tres` — 同乡来访事件资源
- `project.godot` — 新增 `PlotController` autoload 注册

## 预期效果

### 同乡来访（Phase 1 — Tutorial）

游戏启动后，每次 NarrativeOverlay 显示一个事件时 `event_counter` 自动 +1。当第 3 次 xun_tick（进入下个月上旬）时，如果 `event_counter == 2`（即玩家经历了恰好 2 个事件），PlotController 通过 `EventBus.push_event` 推入同乡来访事件到 NarrativeDirector 事件栈，中断当前流程播放剧情。

### Progress 阈值触发（Phase 2 — 归家旅程）

在 755_backhome 时代，玩家点击"赶路"（gan_lu）积累 progress。PlotController 在每旬 tick 时检查：
- `progress >= 31`（>30）且 flag `plot_lishan_triggered` 未设置 → push `backhome_lishan_1`
- `progress >= 61`（>60）且 flag `plot_indifferent_wind_triggered` 未设置 → push `backhome_indifferent_wind_1`

所有防重复 flag 持久化在 PlayerState 中。

## 状态转换

### 同乡来访

1. **计数器递增**：`NarrativeOverlay._on_event_ready_to_play()` → `GameState.event_counter += 1` → `GameSave.data.event_counter += 1`（持久化）
2. **旬推进**：`TimeService.on_xun_tick` → `PlotController._on_xun_tick()` → `_xun_count++`（本地非持久化）
3. **触发判定**：第 3 旬 + event_counter == 2 + flag 未触发 → `EventBus.push_event("plot_prompt_user_action")` → `PlayerState.set_flag("plot_prompt_user_action_triggered", true)`
4. **事件播放**：NarrativeDirector 从 `Database.resolve()` 加载 `plot_prompt_user_action` → 显示同乡叙事 → 选项「收下银钱」→ `money +30`
5. **防重复**：`plot_prompt_user_action_triggered` flag 持久化，读档不会重复触发

### Progress 阈值

1. **progress 积累**：`gan_lu` 行动 success archetype → `prop_add(name=progress; val=xl_progress_gain)` → progress +20
2. **旬推进**：`TimeService.on_xun_tick` → `PlotController._check_progress_triggers()`
3. **骊山触发**：progress >= 31 + `plot_lishan_triggered` 未设置 → push `backhome_lishan_1` + set flag
4. **渭河触发**：progress >= 61 + `plot_indifferent_wind_triggered` 未设置 → push `backhome_indifferent_wind_1` + set flag

## 事件数据

- **uuid**: `plot_prompt_user_action`
- **标题**: 同乡来访
- **描述**: 同乡老张从怀里掏出灰布包裹（30钱），催杜甫去拜谒。天意旁白提示点击右下角「拜谒」行动。
- **选项**: 收下银钱，谢过同乡 → `money +30`

## 进度触发事件

- **uuid**: `backhome_lishan_1` — 骊山事件（progress > 30）
- **uuid**: `backhome_indifferent_wind_1` — 结冰渭河事件（progress > 60）
