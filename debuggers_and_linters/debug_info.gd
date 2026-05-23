extends ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		# Cmd+D (Mac) or Ctrl+D (Windows/Linux)
		if event.keycode == KEY_F1 and (event.meta_pressed or event.ctrl_pressed):
			visible = not visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
