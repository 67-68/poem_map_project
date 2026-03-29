extends TextEdit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("call_controller"):
		visible = !visible
		# 等待0.5s
		await get_tree().create_timer(0.5).timeout

func _on_text_submitted(new_text: String) -> void:
	#breakpoint
	if new_text.split('\n').size() > 1:
		var texts = new_text.split('\n')
		for t in texts:
			parse(t.strip_edges())
		return
	parse(new_text)

func parse(new_text):
	var parts = new_text.split(' ')
	Logging.info('try to execute %s' % new_text)
	if not parts[1]: return
	match parts[1]:
		'send_signal':
			var sig = Global.has_signal(parts[2])
			if not sig: 
				Logging.err('do not found signal %s' % parts[2])
				return
			Global.emit_signal(parts[1],str_to_var(parts[3]))
		'give_trait':
			var trait_ = Global.traits.get(parts[3])
			if not trait_:
				Logging.err('can not found trait %s ' % parts[3])
				return
			PlayerState.traits.append(trait_.uuid)
		'event_result':
			var ev = Global.find_triggerable_item(parts[2])
			if not ev or ev is not BaseEvent:
				Logging.err('can not found event for %s' % parts[2])
				return
			Global.event_shown.emit(ev)
		'add_imaginary':
			Global.request_add_imaginary.emit(parts[2])

	if parts.size() == 2 and parts[0] == '$':
		Global.request_event_key.emit(parts[1])
	elif parts.size() == 2:
		if Global.has_method(parts[0]):
			Global.callv(parts[0],[parts[1]])

func _on_button_pressed() -> void:
	#breakpoint
	var current_text = text
	if not current_text.is_empty():
		_on_text_submitted(current_text)
		text = ""
