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

	# Register hover popup for operator previews
	_register_hover_popup()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(entity)


func _register_hover_popup() -> void:
	var ops: Array = entity.get_meta("operators", []) if entity else []
	if ops.is_empty():
		return

	var vector_lines: Array[String] = []
	for op in ops:
		if op and op.has_method("describe_preview"):
			var desc = op.describe_preview()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	var vector_text = "\n".join(vector_lines)
	if vector_text.is_empty():
		return

	var narrative = entity.name if entity else ""
	if entity and not entity.description.is_empty():
		narrative = narrative + "\n" + entity.description

	var popup = HoverInfoPopup.new()
	popup.set_narrative_text(narrative)
	popup.set_vector_text(vector_text)
	HoverPopupManager.register(self, popup, 0.2, 0.15)
