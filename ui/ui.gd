extends CanvasLayer

var bubble_scene = preload("res://world/dialogue_bubble.tscn")
var queue: PopupQueue

func _ready():
	queue = PopupQueue.new(_draw_chat,EventBus.bubble_complete)
	EventBus.request_add_chat.connect(
		func(item): queue.add_item(item))
	TimeService.play()

func _draw_chat(data):
	if data is ChatBubble:
		if data.attached_node and not is_instance_valid(data.attached_node):
			# 诗人死早了，容错跳过！告诉队列直接下下一个
			queue.mark_as_finish()
			return
			
		var bubble = bubble_scene.instantiate()
		add_child(bubble)
		bubble.setup(data)
		
		# 监听气泡死亡的信号（或者你在气泡的 _input 里直接调用）
		bubble.tree_exited.connect(func(): queue.mark_as_finish())