# SpecialLabel 高亮按钮提示系统

## 概述

当游戏状态触发 `special_label` 提示时（如人际变动、意象获得、属性变化、笔记触发），对应的底部按钮会通过 **单次 Tween** 进入高亮状态（scale 1.06 + modulate 亮白，0.5s），并在提示清除时通过 **单次 Tween** 退出到正常状态（scale 1.0 + modulate WHITE，0.5s）。高亮期间按钮**固定不动，不闪烁不呼吸**。

## 涉及文件

| 文件 | 角色 |
|------|------|
| [`ui/right_info_panel.gd`](ui/right_info_panel.gd) | 唯一实现文件 — 枚举、高亮进出 Tween、提示管线、7s 超时 |
| [`ui/right_info_panel.tscn`](ui/right_info_panel.tscn) | 无需修改 — 5 个按钮节点已存在 |
| [`core/eventbus.gd`](core/eventbus.gd) | 未改动 — 信号连接迁移到 per-button handler（不再监听 toggle 信号做清除） |

## 状态转换

```
IDLE（无活动提示，按钮 scale=1.0, modulate=WHITE）
  │
  │ show_hint(btn_id, text) → _tween_to_highlight (0.5s SINE)
  ▼
HIGHLIGHT（高亮中，定时器 7s 倒计时，按钮 scale=1.06, modulate=BRIGHT，固定不动）
  │
  ├─ 点击目标按钮（btn_id 匹配）→ _tween_to_normal (0.5s SINE) → IDLE
  │
  └─ 7s 超时 → _tween_to_normal (0.5s SINE) → IDLE

新 hint 触发时旧 hint 仍在：
  show_hint() 内部先 _clear_hint()（触发旧按钮的退出 tween），再建新 hint（触发新按钮的进入 tween）
```

## 核心 API

| 方法 | 可见性 | 说明 |
|------|--------|------|
| `show_hint(btn_id, text)` | public | 统一入口：设 SpecialLabel 文本 + 启动目标按钮高亮进入 tween + 7s 定时器 |
| `_clear_hint()` | private | 对旧按钮执行退出高亮 tween + 清文本 + 取消定时器 + 重置 `_active_hint_btn = -1` |
| `_try_clear_on_click(btn_id)` | private | 仅当 `btn_id == _active_hint_btn` 时调 `_clear_hint()` |
| `_tween_to_highlight(btn_id)` | private | 创建单次 scale→1.06 + modulate→BRIGHT tween（SINE, 0.5s），先 kill 旧 tween |
| `_tween_to_normal(btn_id)` | private | 创建单次 scale→1.0 + modulate→WHITE tween（SINE, 0.5s），先 kill 旧 tween |
| `_kill_active_tween(btn_id)` | private | kill 旧 tween 并清理 `_active_tweens` 字典 |
| `set_special_label_text(text)` | public | Tutorial 专用 — 不走高亮管线，直接设置文本 |

## 触发源 → BtnID 映射

| 触发信号 | BtnID | 一次性 flag | 提示文本 Key |
|----------|-------|-------------|-------------|
| `EventBus.on_person_state_changed` | `SOCIAL` | `hint_social_shown` | `UI_RIGHT_INFO_PANEL_TEXT_0` |
| `EventBus.imaginary_changed` | `POEM` | `hint_poem_shown` | `CODE_RIGHT_INFO_PANEL_441BE330DE` |
| `PlayerState.player_stat_changed` (望/兴/势) | `IDEA` | `hint_idea_shown` | `CODE_RIGHT_INFO_PANEL_B593A0EA10` |
| `EventBus.note_triggered` | `NOTE` | `hint_note_shown` | `CODE_RIGHT_INFO_PANEL_3732C36978` |

## 与旧逻辑的差异

| 维度 | 旧逻辑（呼吸） | 新逻辑（单次高亮） |
|------|---------------|-------------------|
| 动画模式 | 无限循环（`set_loops()`） | 单次执行 |
| 高亮期间 | scale 1.0↔1.06 持续闪烁 | scale=1.06 固定不动 |
| Tween 时长 | 1s 扩张 + 1s 收缩 = 2s 周期 | 0.5s 进出统一 |
| 清除时 | kill tween + 直接 snap 重置 scale | kill 旧 tween + tween 动画退出到 normal |
| Hover 交互 | pause/resume 呼吸 | **无** |
| 字段名 | `_breath_tweens` | `_active_tweens` |

## 边缘情况

| 场景 | 行为 |
|------|------|
| 新 hint 触发时旧 hint 仍在 | `show_hint` 先 `_clear_hint()`（触发旧按钮退出 tween）再创建新 hint（触发新按钮进入 tween） |
| 同一按钮连续两次 hint | kill 旧进入 tween → 重新执行进入 tween + 重置 7s 计时器 |
| 高亮中切换到另一个按钮的 hint | 旧按钮 tween 退出到 normal → 新按钮 tween 进入 highlight |
| Tutorial `set_special_label_text` | 不受影响 — 不走高亮管线 |
| Hint flag 已设（已显示过一次） | 不触发，同旧逻辑 |
| 点击非目标按钮 | `_try_clear_on_click` 不匹配 → 无操作 |
| 点击目标按钮时 tween 仍在执行 | `_tween_to_normal` 中 `_kill_active_tween` 先 kill 当前 tween 再启动退出 tween |

## 高亮动画参数

```
scale 高亮：1.06
scale 正常：1.0
modulate 高亮：Color(1.15, 1.15, 1.15, 1.0)
modulate 正常：Color.WHITE
缓动类型：Tween.TRANS_SINE
进出时长：0.5s
模式：单次执行（不循环）
pivot_offset：按钮 size / 2（在 _tween_to_highlight 中动态设置以确保布局完成）
```
