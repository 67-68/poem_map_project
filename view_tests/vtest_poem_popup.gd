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
		1:
			pass
		2:
			pass
		3:
			pass
		_:
			return null
		
	view.custom_minimum_size = Vector2(200,100)
	view.size = Vector2(200,100)
	return view

func create_4level_poem_popup(map):
	var cur_view = map['0']
	if cur_view.is_node_ready():
		var poem = PoemData.new({})
		poem.name = 'test_拾遗'
		poem.example = '\"北风卷地白草折，胡天八月即飞雪\"'
		poem.popularity = 50
		
		var poet = PoetData.new({})
		poet.name = 'test_shiyi'

		cur_view.on_apply_poem(poem,poet)

	cur_view = map['1']
	if cur_view.is_node_ready():
		var poem = PoemData.new({})
		poem.name = 'test_雅颂'
		poem.example = '\"忽如一夜春风来，千树万树梨花开\"'
		poem.popularity = 60

		var poet = PoetData.new({})
		poet.name = 'test_yasong'

		cur_view.on_apply_poem(poem,poet)	

	cur_view = map['2']
	if cur_view.is_node_ready():
		var poem = PoemData.new({})
		poem.name = 'test_瑰意'
		poem.example = '\"海日生残夜，江春入旧年\"'
		poem.popularity = 80
		var poet = PoetData.new({})
		poet.name = 'test_guiyi'

		cur_view.on_apply_poem(poem,poet)
	
	cur_view = map['3']
	if cur_view.is_node_ready():
		var poem = PoemData.new({})
		poem.name = 'test_绝唱'
		poem.example = '\"前不见古人，后不见来者\"'
		poem.popularity = 90
		var poet = PoetData.new({})
		poet.name = 'test_juechang'

		cur_view.on_apply_poem(poem,poet)


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('创建四种等级的poem',create_4level_poem_popup)
	]
