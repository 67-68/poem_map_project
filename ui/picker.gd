extends Control

var _saved_time_scale: float = 1.0

func _ready() -> void:
	EventBus.start_picker.connect(start_picker)
	EventBus.end_picking.connect(func(): hide())
	hide()

func default_constructor(data: GameEntity):
	var entity = preload("res://ui/entity_descriptor.tscn").instantiate()
	entity.initialization(data)
	entity.clicked.connect(on_selected)
	return entity

func on_selected(selected_entity): 
	#breakpoint
	_resume_world()
	EventBus.end_picking.emit(selected_entity) # 如果emit空那么就是没选出来
	hide()
	
func start_picker(data: Array, ui_constructor = default_constructor):
	if not ui_constructor:
		ui_constructor = default_constructor
	for c in $Card/HFlow.get_children():
		c.queue_free()
	for d in data:
		var component = ui_constructor.callv([d])
		$Card/HFlow.add_child(component)
	_pause_world()
	show()


func _on_button_pressed() -> void:
	Logging.warn('玩家没有选择内容')
	_resume_world()
	EventBus.end_picking.emit()


func _pause_world() -> void:
	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)


func _resume_world() -> void:
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
