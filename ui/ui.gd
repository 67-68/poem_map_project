extends CanvasLayer

var bubble_scene = preload("res://world/dialogue_bubble.tscn")
var chat_queue: PopupQueue

func _ready():
	chat_queue = PopupQueue.new(_draw_chat,Global.bubble_complete)
	Global.request_create_bubble.connect(
		func(node: Node2D, text: String):
			chat_queue.add_item(ChatBubble.new({
				"attached_node": node,
				"description": text
	})))

	Global.request_full_chat.connect(
		func(chat: FocusedChat): 
			chat_queue.add_item(chat)
			)

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
		overlay.tree_exited.connect(func(): chat_queue.mark_as_finish())
		
