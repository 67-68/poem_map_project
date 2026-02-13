class_name PoolManager extends Node

var _pool: Array[FloatingText] = []

var _container: Node2D # 所有容器的父节点；垃圾箱

func _ready():
	_container = Node2D.new()
	_container.name = 'PoolContainer'
	_container.z_index = 100
	add_child(_container)

func spawn(content: String, glob_pos: Vector2):
	var instance: FloatingText

	if _pool.is_empty():
		instance = create_new_instance()
	else:
		instance = _pool.pop_back()
	
	instance.move_to_front()
	instance.play(content,glob_pos)

func create_new_instance():
	var inst = Global.FLOAT_TEXT_SCENE.instantiate()
	_container.add_child(inst)
	inst.recycle_requested.connect(_on_recycle_request)
	return inst

func _on_recycle_request(inst: FloatingText):
	inst.hide()
	_pool.append(inst)
