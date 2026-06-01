extends Node

signal user_click_map(data: Variant)

signal place_holder()
signal user_clicked(data: Variant)
signal request_start_black(enable: bool)
signal request_text_popup(text: String)
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
signal request_advance_time(days: int)

signal focus_city_map(enable: bool)
signal selected_actions_change(actions: Array)
signal avaialble_decision_change(decision)

signal show_tombstone_screen(death_reason: String)
signal event_shown(event: Variant)
signal poem_start_clicked()
signal start_picker(data: Array, ui_constructor)
signal end_picking(entity: Variant)
signal push_picker(data: Array, on_selected: Callable, ui_constructor)
signal imaginary_changed()
signal request_add_imaginary(tag: String)
signal on_trait_change()
signal on_flag_change()
signal lianju_score_calculated(score: int)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)
