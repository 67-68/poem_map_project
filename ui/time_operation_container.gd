extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_halt_button_pressed() -> void:
	TimeService.pause()

func _on_time_start_button_pressed() -> void:
	TimeService.play()

func _on_next_poet_button_pressed() -> void:
	if Global.current_selected_poet:
		TimeService.jump_to(
			Global.current_selected_poet.get_next_path_point(
			Global.year).
		point_year)
	else:
		Global.request_text_popup.emit('choose a poet')
