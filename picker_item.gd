class_name PickerItem extends PanelContainer
## 物证木牍卡片 — 极简风格：纸色底 + 朱砂边框 + 单一 Label
##
## 接口：
##   - initialize(entity)  — 填充数据
##   - clicked(entity) 信号 — 点击回调
##   - entity 属性          — 读取当前绑定的 GameEntity

const _HoverInfoPopup = preload("res://ui/hover_info_popup.gd")

signal clicked(entity: GameEntity)

var entity: GameEntity = null
var _pending_data: GameEntity = null

@onready var _label: Label = $Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_label.theme_type_variation = &"DefaultText"
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
		_label.text = "无名"
		Logging.warn("PickerItem._apply_data: entity 为空，显示占位")
		return

	_label.text = entity.name
	Logging.info("PickerItem._apply_data: entity='%s'" % entity.name)
	_register_hover_popup()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Logging.info("PickerItem: 令牌被点击，entity='%s'" % (entity.name if entity else "null"))
		clicked.emit(entity)


func _register_hover_popup() -> void:
	if not entity:
		return
	var ops: Array = entity.get_meta("operators", [])
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

	var narrative = entity.name
	if not entity.description.is_empty():
		narrative += "\n" + entity.description

	var popup = _HoverInfoPopup.new()
	popup.set_narrative_text(narrative)
	popup.set_vector_text(vector_text)
	HoverPopupManager.register(self, popup, 0.2, 0.15)
