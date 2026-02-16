extends CanvasLayer

var bubble_scene = preload("res://world/dialogue_bubble.tscn")
var bubble_queue: PopupQueue

func _ready():
	bubble_queue = PopupQueue.new(_draw_bubble,Global.bubble_complete)
	Global.request_create_bubble.connect(
		func(node: Node2D, text: String):
			bubble_queue.add_item({
				"poet": node,
				"text": text
	}))

func _draw_bubble(data: Dictionary):
	var poet = data.get("poet")
	if not is_instance_valid(poet):      
		# 诗人死早了，容错跳过！告诉队列直接下下一个
		bubble_queue.mark_as_finish()
		return
		
	var bubble = bubble_scene.instantiate()
	add_child(bubble)
	bubble.setup(poet, data.get('text'))
	
	# 监听气泡死亡的信号（或者你在气泡的 _input 里直接调用）
	bubble.tree_exited.connect(func(): bubble_queue.mark_as_finish())

