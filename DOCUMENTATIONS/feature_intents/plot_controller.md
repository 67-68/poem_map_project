# PlotController — 主线剧情控制器

## 涉及文件

- `core/plot_controller.gd` — Autoload，监听 xun_tick 并根据 event_counter/progress/旬计数触发剧情事件
- `core/model/game_save_data.gd` — 新增 `event_counter: int` 字段（含序列化/反序列化）
- `core/game_state.gd` — 新增 `event_counter` 属性代理到 `GameSave.data.event_counter`
- `characters/narrative_overlay.gd` — `_on_event_ready_to_play()` 开头递增 `GameState.event_counter`
- `data/1_core_rules/plot/plot_prompt_user_action.tres` — 同乡来访事件资源
- `data/1_core_rules/plot/libai_tavern_warning.tres` — 李白酒肆劝退事件资源
- `data/1_core_rules/plot/street_exam_rumor.tres` — 街头科举情报事件资源
- `project.godot` — 新增 `PlotController` autoload 注册

## 预期效果

### 同乡来访（Phase 1 — Tutorial）

游戏启动后，每次 NarrativeOverlay 显示一个事件时 `event_counter` 自动 +1。当第 3 次 xun_tick（进入下个月上旬）时，如果 `event_counter == 2`（即玩家经历了恰好 2 个事件），PlotController 通过 `EventBus.push_event` 推入同乡来访事件到 NarrativeDirector 事件栈，中断当前流程播放剧情。

### 天宝六载前置剧情（Phase 1.5 — 旬窗口触发）

在游戏前期（745 年），通过旬计数器 `_xun_count` 窗口触发两个历史背景事件。事件类型为 `RandomEvent` .tres（非 HistoryEvent），调度完全由 PlotController 控制。

- **李白酒肆劝退**（旬 5-8）：`_xun_count` 在 [5, 8] 区间内任意一旬触发。玩家在酒肆遇到被赶出朝廷的李白，李白揭露李林甫操控"野无遗贤"的真相。
- **街头科举情报**（旬 15-20）：`_xun_count` 在 [15, 20] 区间内任意一旬触发。长安街头太学生窃窃私语，透露主考官全是李林甫心腹。

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

### 天宝六载前置剧情

1. **旬推进**：`TimeService.on_xun_tick` → `PlotController._on_xun_tick()` → `_xun_count++`（本地非持久化）
2. **李白触发判定**：`_xun_count` 在 [5, 8] 区间 + flag `plot_libai_warning_triggered` 未设置 → `EventBus.push_event("libai_tavern_warning")` + set flag
3. **传言触发判定**：`_xun_count` 在 [15, 20] 区间 + flag `plot_street_rumor_triggered` 未设置 → `EventBus.push_event("street_exam_rumor")` + set flag
4. **防重复**：两个 flag 持久化在 PlayerState 中，读档不会重复触发
5. **窗口错过**：`_xun_count` 不持久化，读档后从 0 重新计数。若读档时 count 已超出窗口上限则错过事件（flag 未设置，但因为 count 重置为 0 后不再进入窗口，事件永不触发）。这是已知的边角情况，与同乡来访事件一致。

### Progress 阈值

1. **progress 积累**：`gan_lu` 行动 success archetype → `prop_add(name=progress; val=xl_progress_gain)` → progress +20
2. **旬推进**：`TimeService.on_xun_tick` → `PlotController._check_progress_triggers()`
3. **骊山触发**：progress >= 31 + `plot_lishan_triggered` 未设置 → push `backhome_lishan_1` + set flag
4. **渭河触发**：progress >= 61 + `plot_indifferent_wind_triggered` 未设置 → push `backhome_indifferent_wind_1` + set flag

## 事件数据

### 同乡来访
- **uuid**: `plot_prompt_user_action`
- **标题**: 同乡来访
- **描述**: 同乡老张从怀里掏出灰布包裹（30钱），催杜甫去拜谒。天意旁白提示点击右下角「拜谒」行动。
- **选项**: 收下银钱，谢过同乡 → `money +30`

### 李白酒肆劝退
- **uuid**: `libai_tavern_warning`
- **标题**: TRES_LIBAI_TAVERN_WARNING_NAME
- **描述**: 饮酒间李白冷笑揭露李林甫"口蜜腹剑"，天宝六载制举被李林甫亲自把控。杜甫这等狂傲才子去考无异于自寻其辱。
- **选项 A**: 听从李白，放浪形骸 → `money -30` `inspiration +10` `prestige +5` `momentum -2`
- **选项 B**: 我偏要逆天改命 → `inspiration -10`（纯叙事性消耗，无正面增益）

### 街头科举情报
- **uuid**: `street_exam_rumor`
- **标题**: TRES_STREET_EXAM_RUMOR_NAME
- **描述**: 长安街头太学生窃窃私语：皇上虽下诏求贤，但宰相大人放出话来，主考官全是他尚书省的心腹。
- **选项 A**: 心情沉重 → 纯叙事，无属性变化
- **选项 B**: 更加发奋 → `inspiration +6` `health -5`

## 进度触发事件

- **uuid**: `backhome_lishan_1` — 骊山事件（progress >= 31）
- **uuid**: `backhome_indifferent_wind_1` — 结冰渭河事件（progress >= 61）
- **uuid**: `backhome_lost_toy_1` — 遗失拨浪鼓事件（progress >= 79，且玩家持有 rattle_drum trait）

### 遗失拨浪鼓（Phase 2 — 归家旅程·物品损耗）

当 progress >= 79 且玩家持有 rattle_drum trait 时触发。事件 on_enter 阶段自动移除拨浪鼓 trait，给玩家两个选项：
- **回头找找**：消耗一旬时间（time_add day=10），重新获得拨浪鼓 trait
- **算了，赶路要紧**：空选项，拨浪鼓永久丢失

触发条件额外要求 `PlayerState.has_trait("rattle_drum")`，若玩家从未获得拨浪鼓则永不触发。防重复 flag: `plot_lost_toy_triggered`。
