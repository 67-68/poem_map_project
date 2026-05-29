extends PanelContainer

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
	EventBus.end_picking.emit(selected_entity) # 如果emit空那么就是没选出来
	hide()
	
func start_picker(data: Array, ui_constructor = default_constructor):
	if not ui_constructor:
		ui_constructor = default_constructor
	for c in $HFlow.get_children():
		c.queue_free()
	for d in data:
		var component = ui_constructor.callv([d])
		$HFlow.add_child(component)
	show()


func _on_button_pressed() -> void:
	Logging.warn('玩家没有选择内容')
	EventBus.end_picking.emit()
