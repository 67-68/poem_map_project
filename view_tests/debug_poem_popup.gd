class_name DebugPoemPopup extends RefCounted

var view: Control

func create_debug_view(idx: int):
	"""
	每次被调用都会创建对应的view
	"""
	var view_scene := preload('res://features/poem_popup.tscn')
	view = view_scene.instantiate()
	match idx:
		0:
			pass
		_:
			return null
		
	return view

func create_normal_poem_popup(map):
	var cur_view = map['0']
	if cur_view.is_node_ready():
		var poem = PoemData.new({})
		poem.name = 'test_name'
		poem.description = 'test_description'
		poem.popularity = 50
		cur_view.on_apply_poem(poem)

func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('创建正常动画',create_normal_poem_popup)
	]
