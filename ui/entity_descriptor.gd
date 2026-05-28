class_name EntityDescriptor extends PanelContainer

signal clicked(entity_: GameEntity)

@export var entity: GameEntity

func initialization(entity_: GameEntity):
	$V/Name.text = entity_.name
	$V/Description.text = entity_.description
	entity = entity_

func _ready():
	# 检测点击
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(entity)
