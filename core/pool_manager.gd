class_name PoolManager extends Node

var _pool: Array[FloatingText] = []

var _container: CanvasLayer

func _ready():
	_container = CanvasLayer.new()
	_container.name = 'PoolContainer'
	_container.layer = 128  # 高层级确保在 UI 最上方
	add_child(_container)
	
	# 监听飘字信号
	EventBus.request_float_text.connect(_on_request_float_text)

## EventBus 回调：收到飘字请求时从池中取出实例并播放
func _on_request_float_text(content: String) -> void:
	Logging.debug("PoolManager._on_request_float_text: content='%s'" % content)
	spawn(content)

## 播放飘字动画
## content: 显示文本（支持 BBCode）
## config: 可选配置 Dictionary，可覆盖 color/start_scale/end_scale/rise_distance/duration
func spawn(content: String, config: Dictionary = {}):
	var instance: FloatingText

	if _pool.is_empty():
		instance = create_new_instance()
	else:
		instance = _pool.pop_back()
	
	instance.play(content, config)

func create_new_instance():
	var inst = GameConfig.FLOAT_TEXT_SCENE.instantiate()
	_container.add_child(inst)
	inst.recycle_requested.connect(_on_recycle_request)
	return inst

func _on_recycle_request(inst: FloatingText):
	inst.hide()
	_pool.append(inst)
