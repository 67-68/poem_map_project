class_name PoolManager extends Node

var _pool: Array[FloatingText] = []

var _container: Node2D

func _ready():
	_container = Node2D.new()
	_container.name = 'PoolContainer'
	_container.z_index = 100
	add_child(_container)
	
	# 监听飘字信号
	EventBus.request_float_text.connect(_on_request_float_text)

## EventBus 回调：收到飘字请求时从池中取出实例并播放
func _on_request_float_text(content: String, world_pos: Vector2) -> void:
	spawn(content, world_pos)

## 兼容旧接口：直接用 content + world_pos 播放
## 自动判断使用哪种预设配置
func spawn(content: String, glob_pos: Vector2, config: Dictionary = {}):
	var instance: FloatingText

	if _pool.is_empty():
		instance = create_new_instance()
	else:
		instance = _pool.pop_back()
	
	instance.move_to_front()
	instance.play(content, glob_pos, config)

func create_new_instance():
	var inst = GameConfig.FLOAT_TEXT_SCENE.instantiate()
	_container.add_child(inst)
	inst.recycle_requested.connect(_on_recycle_request)
	return inst

func _on_recycle_request(inst: FloatingText):
	inst.hide()
	_pool.append(inst)
