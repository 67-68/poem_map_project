# HoverDisplayFlow — 统一 Hover 显示 + 事件锁

## 文件

- `ui/hover_popup_manager.gd` — HoverDisplayFlow v3.0（FlowType + Delegate + 事件锁）
- `characters/narrative_overlay.gd` — hover 文本渲染 + 事件开始/结束信号
- `characters/tape_visualizer.gd` — 右侧滑入/滑出动画 + 快照恢复
- `ui/action_button.gd` — SLIDE_FROM_RIGHT 消费方
- `ui/scene_action_scroll.gd` — 事件锁（监听信号锁全量 action）
- `picker_item.gd` — BELOW_OVERLAY 消费方
- `characters/event_btn.gd` — BELOW_OVERLAY 消费方
- `ui/left_player_panel.gd` — POPUP_LEGACY 消费方
- `ui/picker_tape_attachment.gd` — 选择时 dismiss_all

## 三种 FlowType

| FlowType | 触发 | Enter | Exit | UI |
|----------|------|-------|------|-----|
| SLIDE_FROM_RIGHT | action hover | 正常：从右侧滑入(0.3s)；事件活跃：直接显示 + ⚠ 前缀 | 1s后滑出 / 行动点击滑出 / 事件活跃直接隐藏 | HoverContainer/HoverLabel |
| BELOW_OVERLAY | picker/event hover | hover_container 直接显示 | 0.15s 后或选择后 hide_hover_text | HoverContainer/HoverLabel |
| POPUP_LEGACY | ambition_hud | 浮动 popup | visible=false | CanvasLayer |

## 事件锁机制

### 状态转换

```
事件开始 (event_display_started)
  → HoverPopupManager.set_event_active(true)
  → SLIDE_FROM_RIGHT 降级：无动画 + 文字前缀"⚠ 请先完成当前事件再选择"
  → SceneActionScroll._lock_all_for_event() 锁所有行动按钮

事件结束 (event_display_ended)
  → HoverPopupManager.set_event_active(false)
  → SLIDE_FROM_RIGHT 恢复滑动动画
  → SceneActionScroll.refresh() 恢复正常状态
```

### 信号流

```
NarrativeOverlay._on_event_ready_to_play
  → event_display_started.emit()
  → SceneActionScroll._lock_all_for_event()

NarrativeOverlay._on_hide_requested
  → event_display_ended.emit()
  → SceneActionScroll._unlock_all_from_event() → refresh()
```

## 动画锁（防颤抖）

`SlideFromRightDelegate`:
- `_animating` 标志：slide-in 期间收到 exit → 排队
- `_pending_exit`：动画完成后执行排队的 slide-out
- enter 期间收到新 enter（用户回来）→ 取消排队
- `_wait_for_anim()`：轮询 tween 状态，最坏 5s 超时

## 快照恢复

`TapeVisualizer`:
- `_store_snapshot()`：`play_show_tape` / `play_show_tape_from_bottom` 首次调用时记录 pos+size
- `restore_snapshot()`：事件开始时 kill tween → 恢复快照位置+size → show + alpha=1.0
- 调用方：`NarrativeOverlay._on_event_ready_to_play`
