class_name TestPopupNotification extends RefCounted

func create_debug_view(idx: int):
	var view_scene := preload('res://ui/pop_up.tscn')
	var view = view_scene.instantiate()
	
	match idx:
		0:
			pass
		_:
			return null
	
	# 务实建议：显式指定大小，防止 HFlowContainer 排版塌陷 💀
	view.custom_minimum_size = Vector2(300, 100)
	return view

func test_action_func(map: Dictionary):
	var cur_view = map.get('0').get_node('Con/TextLabel')
	if cur_view and cur_view.is_node_ready():
		var poet = Util.colorize_underlined_link('李白',Color.GRAY,'')
		var period = Util.colorize_underlined_link('唐朝',Color.GOLD,'')
		var time = Util.colorize_underlined_link('705-755',Color.PERU,'')
		cur_view.text = poet + '是一名' + period + ' ' + time + '诗人'

func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('创建notice', test_action_func)
	]
