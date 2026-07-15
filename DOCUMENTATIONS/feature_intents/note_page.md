# NotePage — 笔记/便签总览页（骨架）

## 设计意图

提供一个全屏覆盖的便签/笔记页面，当前为骨架状态（仅有打开/关闭动画和右上角关闭按钮），内容后续填充。

## 页面布局（当前）

```
┌──────────────────────────────────────────────────────┐
│                                                    X │
│                                                      │
│                  （空 — 内容待填充）                     │
│                                                      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## 状态转换

```
页面初始化（visible = false）
  │
  ├─ EventBus.note_page_toggled 接收 → toggle
  │    ├─ expand == false → show_page()
  │    └─ expand == true  → hide_page()
  │
  ├─ show_page()
  │    ├─ EventBus.narrative_tape_hide_requested (refcount++)
  │    ├─ BlurManager.show_cinematic_blur()
  │    ├─ await 0.5s
  │    ├─ Main.slide_panels_out()
  │    ├─ await 0.65s
  │    ├─ BlurManager.hide_cinematic_blur() + trigger_event_blur()
  │    ├─ 恢复原始 offset
  │    ├─ show() + tween（TRANS_CUBIC EASE_OUT）
  │    └─ expand = true
  │
  └─ hide_page() / X 按钮点击
       ├─ EventBus.narrative_tape_show_requested (refcount--)
       ├─ BlurManager.return_to_hub()
       ├─ Main.slide_panels_in()
       ├─ kill existing tween
       ├─ tween size→(103,47) position→(520,565) + callback hide()
       └─ expand = false
```

## 触发按钮

- [`right_info_panel.tscn`](ui/right_info_panel.tscn:207) 中 `NoteBtn`（带 note_stamp.png 图章图标）
- [`right_info_panel.gd`](ui/right_info_panel.gd:23) 中的 `_note_btn` onready 引用
- 点击 → `EventBus.note_page_toggled.emit()`

## 数据来源

当前骨架无数据依赖。内容填充后在此补充。
