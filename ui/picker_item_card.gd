class_name PickerItemCard extends PanelContainer
## 木牍/令牌卡片 — 优先显示 icon，降级纯文本

signal clicked(entity: GameEntity)

var entity: GameEntity = null

@onready var icon_rect: TextureRect = $V/IconRect
@onready var name_label: Label = $V/NameLabel
@onready var desc_label: Label = $V/DescLabel


func initialize(entity_data: GameEntity) -> void:
	entity = entity_data

	name_label.text = entity.name
	desc_label.text = entity.description

	if entity.icon:
		icon_rect.texture = entity.icon
		icon_rect.show()
	else:
		icon_rect.hide()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(entity)
