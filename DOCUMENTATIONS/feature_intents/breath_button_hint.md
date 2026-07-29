# SpecialLabel 呼吸按钮提示系统

## 概述

当游戏状态触发 `special_label` 提示时（如人际变动、意象获得、属性变化、笔记触发），对应的底部按钮会播放 **scale 呼吸动画**（1.0 ↔ 1.03，SINE 缓动，周期 2s），强化「点击这里」的视觉引导。

## 涉及文件

| 文件 | 角色 |
|------|------|
| [`ui/right_info_panel.gd`](ui/right_info_panel.gd) | 唯一实现文件 — 枚举、呼吸 Tween、提示管线、hover 暂停、7s 超时 |
| [`ui/right_info_panel.tscn`](ui/right_info_panel.tscn) | 无需修改 — 5 个按钮节点已存在 |
| [`core/eventbus.gd`](core/eventbus.gd) | 未改动 — 信号连接迁移到 per-button handler（不再监听 toggle 信号做清除） |

## 状态转换

```
IDLE（无活动提示）
  │
  │ show_hint(btn_id, text)
  ▼
BREATHING（呼吸中，定时器 7s 倒计时）
  │
  ├─ 鼠标进入目标按钮 → tween.pause() → BREATH_PAUSED
  │   └─ 鼠标离开 → tween.play() → BREATHING
  │
  ├─ 点击目标按钮（btn_id 匹配）→ _clear_hint() → IDLE
  │
  └─ 7s 超时 → _clear_hint() → IDLE

新 hint 触发时旧 hint 仍在：
  show_hint() 内部先 _clear_hint() 再建新 hint
```

## 核心 API

| 方法 | 可见性 | 说明 |
|------|--------|------|
| `show_hint(btn_id, text)` | public | 统一入口：设 SpecialLabel 文本 + 启动目标按钮呼吸 + 7s 定时器 |
| `_clear_hint()` | private | 停止呼吸 + 清文本 + 取消定时器 + 重置 `_active_hint_btn = -1` |
| `_try_clear_on_click(btn_id)` | private | 仅当 `btn_id == _active_hint_btn` 时调 `_clear_hint()` |
| `_start_breath(btn_id)` | private | 创建无限循环 scale tween（SINE，周期 2s），设置 `pivot_offset = size / 2` |
| `_stop_breath(btn_id)` | private | kill tween + reset `scale = Vector2(1, 1)` |
| `_on_breath_mouse_entered(btn_id)` | private | 仅活跃按钮暂停呼吸 |
| `_on_breath_mouse_exited(btn_id)` | private | 仅活跃按钮恢复呼吸 |
| `set_special_label_text(text)` | public | Tutorial 专用 — 不走呼吸管线，直接设置文本 |

## 触发源 → BtnID 映射

| 触发信号 | BtnID | 一次性 flag | 提示文本 Key |
|----------|-------|-------------|-------------|
| `EventBus.on_person_state_changed` | `SOCIAL` | `hint_social_shown` | `UI_RIGHT_INFO_PANEL_TEXT_0` |
| `EventBus.imaginary_changed` | `POEM` | `hint_poem_shown` | `CODE_RIGHT_INFO_PANEL_441BE330DE` |
| `PlayerState.player_stat_changed` (望/兴/势) | `IDEA` | `hint_idea_shown` | `CODE_RIGHT_INFO_PANEL_B593A0EA10` |
| `EventBus.note_triggered` | `NOTE` | `hint_note_shown` | `CODE_RIGHT_INFO_PANEL_3732C36978` |

## 与旧逻辑的差异

| 维度 | 旧逻辑 | 新逻辑 |
|------|--------|--------|
| 清除触发 | 点击任意按钮（5 个 EventBus toggle 信号统一清除） | 仅点击被提示的那个按钮才清除 |
| 定时器 | 仅 note 有 5s 定时器 (`_note_hint_timer`) | 统一 7s 定时器 (`_hint_timer`)，所有 hint 类型共用 |
| 动画 | 无 | 目标按钮 scale 呼吸动画 |
| Hover 交互 | 无 | 呼吸中的按钮 hover 时 pause |
| EventBus 连接 | `_clear_special_hint` 连接 5 个 toggle 信号 | 不再监听 toggle 信号（改为在 gui_input handler 中调 `_try_clear_on_click`） |

## 边缘情况

| 场景 | 行为 |
|------|------|
| 新 hint 触发时旧 hint 仍在 | `show_hint` 先 `_clear_hint()` 再创建 |
| 同一按钮连续两次 hint | kill 旧 tween → 重建 + 重置 7s 计时器 |
| 呼吸中切换到另一个按钮的 hint | 旧按钮 tween kill + scale reset → 新按钮启动呼吸 |
| Tutorial `set_special_label_text` | 不受影响 — 不走呼吸管线 |
| Hint flag 已设（已显示过一次） | 不触发，同旧逻辑 |
| 点击非目标按钮 | `_try_clear_on_click` 不匹配 → 无操作 |
| Hover 非目标按钮 | `_on_breath_mouse_entered` 中 `btn_id != _active_hint_btn` → return |

## 呼吸动画参数

```
scale 范围：1.0 ↔ 1.03
缓动类型：Tween.TRANS_SINE
完整周期：2.0s（扩张 1s + 收缩 1s）
循环模式：无限循环（set_loops()）
pivot_offset：按钮 size / 2（在 _start_breath 中动态设置以确保布局完成）
```
