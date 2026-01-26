extends LineEdit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("call_controller"):
		visible = !visible

func _on_text_submitted(new_text: String) -> void:
	var parts = new_text.split(' ')
	Logging.info('try to execute %s' % new_text)
	if parts.size() == 3 and parts[0] == '$':
		var sig = Global.has_signal(parts[1])
		if not sig: 
			Logging.err('do not found signal %s' % parts[1])
			return
		Global.emit_signal(parts[1],str_to_var(parts[2]))
	elif parts.size() == 2:
		if Global.has_method(parts[0]):
			Global.callv(parts[0],parts[1])
	
