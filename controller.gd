extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		# Cmd+D (Mac) or Ctrl+D (Windows/Linux)
		if event.keycode == KEY_F2 and (event.meta_pressed or event.ctrl_pressed):
			visible = not visible

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
			var sig = EventBus.has_signal(parts[2])
			if not sig:
				Logging.err('do not found signal %s' % parts[2])
				return
			EventBus.emit_signal(parts[2],str_to_var(parts[3]))
		'give_trait':
			var trait_ = Database.traits.get(parts[3])
			if not trait_:
				Logging.err('can not found trait %s ' % parts[3])
				return
			PlayerState.traits.append(trait_.uuid)
		'event_result':
			var ev = Database.find_triggerable_item(parts[2])
			# 🤓☝️ 鸭子类型：检查对象是否具有事件的必要属性
			if not ev or not ev.has_method("get") or ev.get("uuid") == null or ev.get("options") == null:
				Logging.err('can not found event for %s' % parts[2])
				return
			EventBus.event_shown.emit(ev)
		'add_imaginary':
			EventBus.request_add_imaginary.emit(parts[2])

	if parts.size() == 2 and parts[0] == '$':
		EventBus.request_event_key.emit(parts[1])
	elif parts.size() == 2:
		if GameState.has_method(parts[0]):
			GameState.callv(parts[0],[parts[1]])
		elif Database.has_method(parts[0]):
			Database.callv(parts[0],[parts[1]])
		elif PlayerState.has_method(parts[0]):
			PlayerState.callv(parts[0],[parts[1]])

func _on_button_pressed() -> void:
	#breakpoint
	var current_text = $Controller.text
	if not current_text.is_empty():
		_on_text_submitted(current_text)
		$Controller.text = ""
