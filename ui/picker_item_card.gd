class_name PickerItemCard extends PanelContainer
## 木牍/令牌卡片 — 优先显示 icon，降级纯文本

signal clicked(entity: GameEntity)

var entity: GameEntity = null
var _pending_data: GameEntity = null

@onready var icon_rect: TextureRect = $V/IconRect
@onready var name_label: Label = $V/NameLabel
@onready var desc_label: Label = $V/DescLabel


func _ready() -> void:
	name_label.theme_type_variation = &"DefaultText"
	desc_label.theme_type_variation = &"DefaultText"
	if _pending_data:
		_apply_data(_pending_data)
		_pending_data = null


func initialize(entity_data: GameEntity) -> void:
	if not is_node_ready():
		_pending_data = entity_data
		return
	_apply_data(entity_data)


func _apply_data(entity_data: GameEntity) -> void:
	entity = entity_data
	if not entity:
		name_label.text = "无名"
		desc_label.text = ""
		return

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
