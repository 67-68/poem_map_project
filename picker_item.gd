class_name PickerItem extends PanelContainer
## 物证木牍卡片 — 极简风格：纸色底 + 朱砂边框 + 单一 Label
##
## 接口：
##   - initialize(entity)  — 填充数据
##   - clicked(entity) 信号 — 点击回调
##   - entity 属性          — 读取当前绑定的 GameEntity

signal clicked(entity: GameEntity)

var entity: GameEntity = null
var _pending_data: GameEntity = null

@onready var _label: Label = $Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_label.theme_type_variation = &"DefaultText"
	mouse_entered.connect(_on_mouse_entered_picker)
	mouse_exited.connect(_on_mouse_exited_picker)
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


func _on_mouse_entered_picker() -> void:
	Logging.info("PickerItem._on_mouse_entered_picker: mouse entered, entity='%s'" % (entity.name if entity else "null"))


func _on_mouse_exited_picker() -> void:
	Logging.info("PickerItem._on_mouse_exited_picker: mouse exited, entity='%s'" % (entity.name if entity else "null"))


func _register_hover_popup() -> void:
	Logging.info("PickerItem._register_hover_popup: 开始注册 hover (BELOW_OVERLAY), entity='%s'" % (entity.name if entity else "null"))
	if not entity:
		Logging.warn("PickerItem._register_hover_popup: entity 为空，跳过注册")
		return
	var ops: Array = entity.get_meta("operators", [])
	var sub_action_preview: String = entity.get_meta("sub_action_preview", "")
	Logging.info("PickerItem._register_hover_popup: 获取到 %d 个 operators, sub_action_preview='%s'" % [ops.size(), "yes(%d chars)" % sub_action_preview.length() if not sub_action_preview.is_empty() else "no"])

	var vector_lines: Array[String] = []

	if not sub_action_preview.is_empty():
		vector_lines.append(sub_action_preview)
		Logging.info("PickerItem._register_hover_popup: sub_action_preview 非空，跳过 archetype operators 独立展示")
	else:
		var op_lines := ActionHintBuilder.build_operator_preview(ops)
		vector_lines.append_array(op_lines)
		Logging.info("PickerItem._register_hover_popup: ActionHintBuilder 生成 %d 行 operator 描述" % op_lines.size())
	
	var vector_text := "\n".join(vector_lines)
	Logging.info("PickerItem._register_hover_popup: 生成 vector_text, 共 %d 行" % vector_lines.size())
	if vector_text.is_empty():
		Logging.info("PickerItem._register_hover_popup: vector_text 为空，跳过注册")
		return

	var narrative := entity.name
	if not entity.description.is_empty():
		narrative += "\n" + entity.description
		Logging.info("PickerItem._register_hover_popup: 附加 description 到 narrative")

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("PickerItem._register_hover_popup: hover 注册完成 (BELOW_OVERLAY), entity='%s'" % entity.name)
