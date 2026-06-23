# 音效对照表 (Sound Effects Reference)

> 最后更新: 2026-06-21  
> 音效系统架构基于 [`UISoundComponent`](features/ui_sound_component.gd) + [`AudioManager`](core/audio_manager.gd) autoload

---

## 1. 语义 → 文件夹映射

| 序号 | 语义名称 | 文件夹 | 感官联想 | 音频文件数 |
|------|---------|--------|---------|-----------|
| S1 | `book_impact` | `assets/sounds/book_impact/` | 木制按钮按下，硬质碰撞 | 5 |
| S2 | `book_flip` | `assets/sounds/book_flip/` | 纸张快速翻动 / 悬停 | 2 |
| S3 | `stamp_impact` | `assets/sounds/stamp_impact/` | 印章 / 抉择重击 | 5 |
| S4 | `bell_impact` | `assets/sounds/bell_impact/` | 钟声 / 时间流逝 | 5 |
| S5 | `ink_flip` | `assets/sounds/ink_flip/` | 毛笔书写 / 吐字 | 3 |
| S6 | `book_place` | `assets/sounds/book_place/` | 纸卷放在桌面 / 事件降临 | 3 |
| S7 | `book_friction` | `assets/sounds/book_friction/` | 纸张拖动摩擦 | 1 |
| S8 | `heartbeat` | `assets/sounds/heartbeat/` | 濒死心跳（循环播放） | 2 |

---

## 2. 分发清单

### 2.1 S1 — `book_impact`（木制按钮点击）

**触发机制**: [`UISoundComponent`](features/ui_sound_component.gd) 自动检测父节点 `pressed` / `toggled` / `item_selected` / `confirmed` 信号

| 文件 | 挂载节点 | 注入方式 |
|------|---------|---------|
| [`main_menu.tscn`](main_menu.tscn:45) | Start Button | TSCN ext_resource |
| [`main_menu.tscn`](main_menu.tscn:55) | Quit Button | TSCN ext_resource |
| [`main_menu.tscn`](main_menu.tscn:64) | Setting Button | TSCN ext_resource |
| [`controller.tscn`](controller.tscn:39) | Button | TSCN ext_resource |
| [`ui/poem_start.tscn`](ui/poem_start.tscn:30) | Button | TSCN ext_resource |
| [`ui/poem_crafter.tscn`](ui/poem_crafter.tscn:86) | InputImagPanel/Button | TSCN ext_resource |
| [`ui/decision_panel.tscn`](ui/decision_panel.tscn:56) | ActionPanel/V/MarginContainer/Button | TSCN ext_resource |
| [`ui/tomb_stone_screen.tscn`](ui/tomb_stone_screen.tscn:70) | ColorRect/Button | TSCN ext_resource |
| [`ui/event_ui.tscn`](ui/event_ui.tscn:32) | InterruptBtn | TSCN ext_resource |
| [`ui/system_menu.tscn`](ui/system_menu.tscn:43) | ContinueBtn | TSCN ext_resource |
| [`ui/system_menu.tscn`](ui/system_menu.tscn:53) | ReturnBtn | TSCN ext_resource |
| [`ui/left_player_panel.tscn`](ui/left_player_panel.tscn:76) | Ambition LinkButton | TSCN ext_resource |
| [`characters/event_btn.gd`](characters/event_btn.gd:30) | 动态创建的 EventBtn | 代码注入 (`preload` + `add_child`) |
| [`ui/imaginery_item.tscn`](ui/imaginery_item.tscn:18) | ImagineryItem (custom signal: `imagenery_item_clicked`) | TSCN ext_resource |
| [`ui/poem_slot.tscn`](ui/poem_slot.tscn:19) | PoemSlot (custom signal: `slot_clicked`) | TSCN ext_resource |
| [`ui/ambition_widget.gd`](ui/ambition_widget.gd:19) | toggle_btn | 代码注入 |
| [`world/map.gd`](world/map.gd:95) | 地图州府点击 | 直接调用 `AudioManager.play_sfx_category()` |

---

### 2.2 S2 — `book_flip`（纸张翻动 / 悬停）

**按钮 hover**: [`UISoundComponent`](features/ui_sound_component.gd) 自动检测父节点 `mouse_entered` / `focus_entered` 信号

| 文件 | 触发场景 | 注入方式 |
|------|---------|---------|
| [`main_menu.tscn`](main_menu.tscn:46) | Start Button hover | TSCN |
| [`main_menu.tscn`](main_menu.tscn:56) | Quit Button hover | TSCN |
| [`main_menu.tscn`](main_menu.tscn:65) | Setting Button hover | TSCN |
| [`characters/event_btn.gd`](characters/event_btn.gd:31) | EventBtn hover | 代码注入 |
| [`picker_item.tscn`](picker_item.tscn:27) | PickerItem hover | TSCN |
| [`ui/picker_item_card.tscn`](ui/picker_item_card.tscn:20) | PickerItemCard hover | TSCN |
| [`ui/imaginery_item.tscn`](ui/imaginery_item.tscn:19) | ImagineryItem hover | TSCN |
| [`ui/poem_slot.tscn`](ui/poem_slot.tscn:20) | PoemSlot hover | TSCN |

**非按钮跳过/快进**:

| 文件 | 触发场景 | 调用位置 |
|------|---------|---------|
| [`characters/event_ui.gd`](characters/event_ui.gd:584) | 用户左键点击跳过打字机 | `_input()` |
| [`ui/cinematic_overlay.gd`](ui/cinematic_overlay.gd:35) | Cmd+Space 跳过过场 | `_input()` |
| [`ui/cinematic_overlay.gd`](ui/cinematic_overlay.gd:44) | 点按 Dimmer 快进过场 | `_on_dimmer_gui_input()` |
| [`world/dialogue_bubble.gd`](world/dialogue_bubble.gd:53) | 点击推进对话气泡 | `_input()` |

---

### 2.3 S3 — `stamp_impact`（印章重击）

**触发机制**: [`UISoundComponent`](features/ui_sound_component.gd) 通过 `custom_click_signal = "clicked"` 监听选择器组件的特定信号

| 文件 | 挂载节点 | 注入方式 |
|------|---------|---------|
| [`picker_item.tscn`](picker_item.tscn:26) | PickerItem | TSCN |
| [`ui/picker_item_card.tscn`](ui/picker_item_card.tscn:19) | PickerItemCard | TSCN |
| [`ui/settlement_tape_entry.gd`](ui/settlement_tape_entry.gd:108) | 结算纸带确认按钮 | 代码注入 |
| [`ui/picker_tape_attachment.gd`](ui/picker_tape_attachment.gd:69) | PickerTapeAttachment 动画完成回调 | 直接调用 `AudioManager.play_sfx_category()` |

---

### 2.4 S4 — `bell_impact`（时间流逝钟声）

**触发机制**: [`UISoundComponent`](features/ui_sound_component.gd) 挂在 time_control_panel 的三个时间控制按钮上

| 文件 | 挂载节点 | 语义 |
|------|---------|------|
| [`world/time_control_panel.tscn`](world/time_control_panel.tscn:91) | SpeedDown Button | 减速 |
| [`world/time_control_panel.tscn`](world/time_control_panel.tscn:102) | FlowPause Button | 暂停 |
| [`world/time_control_panel.tscn`](world/time_control_panel.tscn:113) | SpeedUp Button | 加速 |

---

### 2.5 S5 — `ink_flip`（毛笔书写吐字）

| 文件 | 触发场景 | 节流策略 |
|------|---------|---------|
| [`characters/event_ui.gd`](characters/event_ui.gd:476) | 打字机 BBCode 块整体吐出 | 每次一个 BBCode 段 |
| [`characters/event_ui.gd`](characters/event_ui.gd:494) | 打字机逐字吐出普通文本 | `literal_char_count % 3 == 0`（每3字） |
| [`ui/ambition_hud.gd`](ui/ambition_hud.gd:101) | 雄心进度条更新 | 每次 `_update_progress()` |

---

### 2.6 S6 — `book_place`（纸卷降临）

| 文件 | 触发场景 | 调用位置 |
|------|---------|---------|
| [`characters/event_ui.gd`](characters/event_ui.gd:384) | 事件纸带 entry 创建时（slow 模式） | `display_slow()` 入口 |

---

### 2.7 S7 — `book_friction`（纸张拖拽摩擦）

| 文件 | 触发场景 | 调用位置 |
|------|---------|---------|
| [`ui/smooth_scroll_container.gd`](ui/smooth_scroll_container.gd:98) | 鼠标左键按下开始拖拽纸带 | `_input()` 拖拽开始分支 |

---

### 2.8 S8 — `heartbeat`（濒死心跳循环）

**播放方式**: 独立 `_loop_player` AudioStreamPlayer，使用 `AudioManager.play_sfx_loop()` / `stop_sfx_loop()` 启停

| 文件 | 触发条件 | 停止条件 |
|------|---------|---------|
| [`core/survival_manager.gd`](core/survival_manager.gd:145) | `健康 ≤ 20` 且 `> 0` | 健康恢复 > 20 或角色死亡 |
| [`core/survival_manager.gd`](core/survival_manager.gd:148) | — | 健康恢复时 `stop_sfx_loop()` |
| [`core/survival_manager.gd`](core/survival_manager.gd:158) | — | 死亡判定时 `stop_sfx_loop()` |

---

## 3. 架构说明

### 3.1 UISoundComponent（挂件模式）

[`UISoundComponent`](features/ui_sound_component.gd) 是一个可复用的 `Node` 子类，挂载到任意 UI 控件下即可自动监听信号并播放音效。

```
父节点 (Button / Control)
├── UISoundComponent        ← 挂件
│   ├── click_category      ← 点击音效分类
│   ├── hover_category      ← 悬停音效分类
│   ├── custom_click_signal ← 自定义信号名（可选）
│   ├── pitch_randomness    ← 音高随机度
│   └── enable_jitter       ← 节奏抖动
└── ...其他子节点
```

**信号自动检测优先级**（click）:
1. 若 `custom_click_signal` 非空 → 连接指定信号
2. 否则依次检测 `pressed`、`toggled`、`item_selected`、`confirmed`

**信号自动检测优先级**（hover）:
1. `mouse_entered`
2. `focus_entered`

### 3.2 AudioManager（autoload 中枢）

[`AudioManager`](core/audio_manager.gd) 通过以下 API 暴露音效播放：

| API | 用途 | 播放器 |
|-----|------|--------|
| `play_sfx_category(category, pitch_randomness, volume_db)` | 从分类目录随机选一个文件播放 | SFX Pool (8通道轮询) |
| `play_sfx_loop(category, pitch_randomness, volume_db)` | 循环播放分类音效 | 独立 `_loop_player` |
| `stop_sfx_loop()` | 停止循环音效 | `_loop_player` |
| `is_sfx_loop_playing()` | 查询循环播放状态 | `_loop_player` |

---

## 4. 全部音频资产清单

| 目录 | 文件名 | 格式 |
|------|--------|------|
| `bell_impact/` | `impactBell_heavy_000` ~ `004` | OGG |
| `book_flip/` | `bookFlip1`, `bookFlip2` | OGG |
| `book_friction/` | `bookFriction` | OGG |
| `book_impact/` | `impactWood_heavy_000` ~ `004` | OGG |
| `book_place/` | `bookPlace1` ~ `bookPlace3` | OGG |
| `heartbeat/` | `impactWood_heavy_003`, `impactWood_heavy_004` | OGG |
| `ink_flip/` | `drawKnife1` ~ `drawKnife3` | OGG |
| `stamp_impact/` | `impactPunch_medium_000` ~ `004` | OGG |

> **未使用的目录**: `assets/sounds/book_open/`, `assets/sounds/coin/`, `assets/sounds/leather/` — 保留供后续扩展

---

## 5. 添加新音效指南

1. **增加新语义分类**: 在 `assets/sounds/` 下新建目录，放入 `.ogg` 文件
2. **按钮类**: 在 TSCN 中添加 `UISoundComponent` 子节点，设置 `click_category` / `hover_category`
3. **非按钮类**: 在代码中直接调用 `AudioManager.play_sfx_category("分类名")`
4. **循环类**: 调用 `AudioManager.play_sfx_loop("分类名")`，在适当时机调用 `stop_sfx_loop()`
5. **节流**: 高频触发场景（如打字机）使用 `i % N == 0` 或时间阈值控制播放频率

---

## 6. Ambient System（环境背景音系统）

> 新增于 2026-06-23  
> 实现文件: [`AudioManager`](core/audio_manager.gd) + [`AmbientAudioOperator`](core/operators/ambient_audio_operator.gd)

### 6.1 概念

Ambient System 提供**多层叠加的环境背景音**，用于营造空间氛围（如风雪呼啸、虫鸣底噪）。每一层是独立的 `AudioStreamPlayer`，可以同时播放。

与 BGM 系统自动互斥：BGM 播放时 ambient 自动暂停，BGM 停止后自动恢复。Loop/SFX 不受影响。

### 6.2 层数据结构

每层由以下字段定义（`Dictionary` 格式）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `streams` | `AudioStream` 或 `Array[AudioStream]` | 是 | 曲目池。单个流或数组 |
| `volume_db` | `float` | 否 | 该层独立音量，默认 0.0 |
| `replay_gap` | `float` | 否 | `0` = 连续循环；`> 0` = 播完后等待 N 秒再随机选曲重播 |
| `replay_gap_max` | `float` | 否 | 仅 `replay_gap > 0` 时有效，实际间隔 = `randf_range(replay_gap, replay_gap_max)` |

### 6.3 API

| 方法 | 参数 | 说明 |
|------|------|------|
| `AudioManager.register_ambient_profile(key, layers)` | `key: String`, `layers: Array[Dictionary]` | 注册一个 ambient profile |
| `AudioManager.set_ambient_profile(key)` | `key: String` | 激活指定 profile（先 clear 旧的）。BGM 在播时自动暂停 |
| `AudioManager.clear_ambient_profile()` | — | 停止并清理所有 ambient 层 |
| `AudioManager.pause_ambient()` | — | 暂停所有层 |
| `AudioManager.resume_ambient()` | — | 恢复所有层 |
| `AudioManager.is_ambient_active()` | — | 查询 ambient 是否激活 |

### 6.4 Operator 控制

通过 [`AmbientAudioOperator`](core/operators/ambient_audio_operator.gd) 在事件中控制：

```tres
[sub_resource type="Resource" id="ambient_op"]
script = ExtResource("ambient_audio_operator")
action = "set_profile"
profile_key = "755_backhome"
```

| action 值 | 说明 |
|-----------|------|
| `"set_profile"` | 激活 `profile_key` 指定的 profile |
| `"clear"` | 停止所有 ambient |

### 6.5 当前已注册的 Profile

#### 6.5.1 `755_backhome` — 极寒风雪（低吼 + 尖啸）

注册位置: [`main.gd`](main.gd:238) `_register_ambient_profiles()`

| Layer | 语义 | 音频 | volume | replay_gap |
|-------|------|------|--------|------------|
| 0 (Void) | 连续低频底噪 | `low_wind.wav` | 0 dB | 0 (连续) |
| 1 (Attack) | 随机狂风尖啸 | `harsh_wind.wav` | -8 dB | 25~30s 间隔 |

### 6.6 架构决策

- **BGM 互斥**: 由 `AudioManager._process()` 被动监控 `_bgm_track_1/2.playing`，不修改 `play_music()` 代码
- **Loop/SFX 不管**: `play_sfx_loop()` / `play_sfx()` 不触发 ambient 暂停
- **profile 激活时机**: 通过 operator 在事件中触发（如进入特定时代/场景的第一个事件），而非硬编码在场景切换逻辑中
