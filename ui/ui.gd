extends CanvasLayer

var bubble_scene = preload("res://world/dialogue_bubble.tscn")
var chat_queue: PopupQueue

func _ready():
	chat_queue = PopupQueue.new(_draw_chat,Global.bubble_complete)
	Global.request_add_chat.connect(
		func(item):
			chat_queue.add_item(item))

func _draw_chat(data):
	if data is ChatBubble:
		if data.attached_node and not is_instance_valid(data.attached_node):      
			# 诗人死早了，容错跳过！告诉队列直接下下一个
			chat_queue.mark_as_finish()
			return
			
		var bubble = bubble_scene.instantiate()
		add_child(bubble)
		bubble.setup(data)
		
		# 监听气泡死亡的信号（或者你在气泡的 _input 里直接调用）
		bubble.tree_exited.connect(func(): chat_queue.mark_as_finish())

	elif data is FocusedChat:
		var overlay = preload("res://ui/focus_chat_overlay.tscn").instantiate()
		add_child(overlay)
		
		# 把长长的对话数组塞给它，让它自己去播
		overlay.play_dialogue_sequence(data)
		
		# 同样监听它的销毁信号，用来推进队列
		if overlay.has_signal('chat_finished'):
			overlay.chat_finished.connect(finish_chat)	
		else:
			Logging.warn('some overlay do not have chat finished signal. connect to normal tree exit may cause logic chaos')
			overlay.tree_exited.connect(finish_chat)

func finish_chat(result: ChoiceResult = null):
	chat_queue.mark_as_finish()
	if result:
		var next_item = Global.find_triggerable_item(result.target_uuid)
		if next_item:
			if next_item is FocusedChat:
				chat_queue.add_item(next_item)
			elif next_item is ChatBubble:
					chat_queue.add_item(next_item)
			else:
					Logging.warn('what is this item? Check if the uuid mess up. Same uuid for different field data')
					Logging.warn('target: %s next: %s' % [result.target_uuid,next_item.uuid])
		else:
			Logging.warn('can not find a valid uuid for a triggerable item in data: %s' % result.target_uuid)
