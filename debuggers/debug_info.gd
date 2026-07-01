extends ColorRect


func _ready() -> void:
	visible = false
	set_process_input(true)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and (event.meta_pressed or event.ctrl_pressed):
			visible = not visible
