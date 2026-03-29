extends PanelContainer

func _ready() -> void:
	Global.start_picker.connect(start_picker)
	Global.end_picking.connect(func(): hide())
	hide()

func default_constructor(data: GameEntity, callback: Callable):
	var entity = preload("res://ui/entity_descriptor.tscn").instantiate()
	entity.initialization(data)
	entity.clicked.connect(func(selected_entity): 
		Global.end_picking.emit(selected_entity)
		hide()
	)
	return entity

func start_picker(data: Array, callback: Callable, ui_constructor: Callable = default_constructor):
	for c in $HFlow.get_children():
		c.queue_free()
	for d in data:
		var component = ui_constructor.callv([d, callback])
		$HFlow.add_child(component)
	show()