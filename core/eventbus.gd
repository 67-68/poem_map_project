extends Node

signal user_click_map(data: Variant)

signal place_holder()
signal user_clicked(data: Variant)
signal request_start_black(enable: bool)

# ── 飘字/通知系统信号 ───────────────────────────────────
# [新] 屏幕 UI 飘字 (FloatingText)
# content: 模糊文本 (支持 BBCode), 如 "[color=#FFD700]塞外风情[/color]"
# 自动定位到屏幕顶部居中，无需传入位置参数
signal request_float_text(content: String)
# [新] UI Toast (合并 SimpleToast + pop_up)
# content: 文本内容
# type: 0=普通提示, 1=警告
signal request_toast(content: String, type: int)
# ────────────────────────────────────────────────────────

# @deprecated 改用 request_toast(content, 0)
signal request_text_popup(text: String)
# @deprecated 改用 request_toast(content, 1)
signal request_warning_toast(data: String)

signal request_rain(enable: bool)
signal request_daylight(enable: bool)

signal year_changed(year: float)
signal speed_changed(speed: float)

signal poems_created(data: Array)
signal request_apply_poem(data: Variant, poet: Variant)
signal poem_animation_finished()

signal request_add_messager(msg: Variant)
signal request_change_bg_modulate(color: Color)
signal request_restore_bg_modulate(duration: float)
signal event_confirmed()

signal request_change_left_panel_visibility(enable)
signal request_event(data: Variant, context: Dictionary)
signal request_event_key(key: String, context: Dictionary)
signal push_event(data: Variant, context: Dictionary)
signal pop_event()
signal pop_to_event(event_key: String)
signal bubble_complete()
signal request_add_chat(data: Variant)

# --- FocusChat 栈条目（仿 Picker/Cinematic 模式）--------
signal push_focused_chat(data: Variant)    # 触发方 → NarrativeOverlay: 推入栈
signal focused_chat_start(data: Variant)   # NarrativeOverlay → FocusChatOverlay: 开始播放
signal focused_chat_finished(result: Variant) # FocusChatOverlay → NarrativeOverlay: 播放完毕

signal request_advance_time(days: int)

signal focus_city_map(enable: bool)
signal selected_actions_change(actions: Array)
## 锁定行动被选中时广播，携带被锁定的 SceneAction 数组
## ActionMap 监听此信号对按钮施加闪光效果
signal locked_actions_selected(actions: Array)
## 请求 SceneActionScroll 刷新行动面板（事件链结束后恢复 UI 状态）
signal request_refresh_action_panel()
signal avaialble_decision_change(decision)

signal show_tombstone_screen(death_reason: String)
signal event_shown(event: Variant)
signal poem_start_clicked()
signal start_picker(data: Array, ui_constructor)
signal end_picking(entity: Variant)
signal push_picker(data: Array, on_selected: Callable, ui_constructor)
signal push_cinematic(texts: Array[String])
signal cinematic_start(texts: Array[String])
signal cinematic_finished()
signal imaginary_changed()
signal request_add_imaginary(tag: String)
signal on_trait_change()
signal on_flag_change()
signal lianju_score_calculated(score: int)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)
