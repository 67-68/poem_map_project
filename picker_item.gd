class_name PickerItem extends PanelContainer
## 物证木牍卡片 — 极简风格：纸色底 + 朱砂边框 + 单一 Label
##
## 接口：
##   - initialize(entity)  — 填充数据
##   - set_locked(reason)   — 灰化锁定（属性不满足时可见但不可选）
##   - set_unlocked()       — 解除灰化
##   - clicked(entity) 信号 — 点击回调（锁定态不发射）
##   - entity 属性          — 读取当前绑定的 GameEntity

signal clicked(entity: GameEntity)

var entity: GameEntity = null
var _pending_data: GameEntity = null

## 🆕 灰化锁定态：属性不满足但可见，点击时 toast 告知原因
var _is_locked: bool = false
var _locked_reason: String = ""

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
		_label.text = tr("CODE_PICKER_ITEM_CC479D8361")
		Logging.warn("PickerItem._apply_data: entity 为空，显示占位")
		return

	_label.text = entity.name
	Logging.info("PickerItem._apply_data: entity='%s'" % entity.name)
	
	# 🆕 从 entity meta 读取锁定状态（由 action_button 构建 picker 数据时注入）
	var meta_locked: bool = entity.get_meta("_is_locked", false)
	var meta_reason: String = entity.get_meta("_locked_reason", "")
	if meta_locked:
		set_locked(meta_reason)
		Logging.info("PickerItem._apply_data: entity='%s' 从 meta 加载锁定态, reason='%s'" % [entity.name, meta_reason])
	
	_register_hover_popup()


## 🆕 设置为灰化锁定态。点击时弹出 toast 告知原因。
func set_locked(reason: String) -> void:
	_is_locked = true
	_locked_reason = reason
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Logging.info("PickerItem.set_locked: entity='%s', reason='%s'" % [entity.name if entity else "null", reason])
	_refresh_hover_popup()


## 🆕 解除灰化锁定态。
func set_unlocked() -> void:
	_is_locked = false
	_locked_reason = ""
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	Logging.info("PickerItem.set_unlocked: entity='%s'" % (entity.name if entity else "null"))
	_refresh_hover_popup()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Logging.info("PickerItem: 令牌被点击，entity='%s', _is_locked=%s" % [entity.name if entity else "null", str(_is_locked)])
		
		# 🆕 锁定态拦截：弹出 toast，不发射 clicked
		if _is_locked:
			var toast_reason := _locked_reason if not _locked_reason.is_empty() else tr("CODE_SUB_ACTION_BUTTON_5DB17E4310")
			EventBus.request_toast.emit(toast_reason, 1)
			Logging.info("PickerItem: 锁定态点击被拦截, entity='%s', reason='%s'" % [entity.name if entity else "null", toast_reason])
			return
		
		clicked.emit(entity)


func _on_mouse_entered_picker() -> void:
	Logging.info("PickerItem._on_mouse_entered_picker: mouse entered, entity='%s', _is_locked=%s" % [entity.name if entity else "null", str(_is_locked)])


func _on_mouse_exited_picker() -> void:
	Logging.info("PickerItem._on_mouse_exited_picker: mouse exited, entity='%s'" % (entity.name if entity else "null"))


## 🆕 注销旧 popup 并重建（set_locked / set_unlocked 后刷新 hover 内容）
func _refresh_hover_popup() -> void:
	if not entity:
		Logging.warn("PickerItem._refresh_hover_popup: entity 为空，跳过")
		return
	HoverPopupManager.unregister(self)
	_register_hover_popup()
	Logging.info("PickerItem._refresh_hover_popup: refreshed for '%s'" % entity.name)


func _register_hover_popup() -> void:
	Logging.info("PickerItem._register_hover_popup: 开始注册 hover (BELOW_OVERLAY), entity='%s', _is_locked=%s" % [entity.name if entity else "null", str(_is_locked)])
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

	# 🆕 锁定态时叙事层前置锁原因
	var narrative := entity.name
	if _is_locked and not _locked_reason.is_empty():
		narrative = "[color=#cc6666]🔒 %s[/color]\n\n%s" % [_locked_reason, entity.name]
		Logging.info("PickerItem._register_hover_popup: 锁定态叙事前置, reason='%s'" % _locked_reason)
	if not entity.description.is_empty():
		narrative += "\n" + entity.description
		Logging.info("PickerItem._register_hover_popup: 附加 description 到 narrative")

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("PickerItem._register_hover_popup: hover 注册完成 (BELOW_OVERLAY), entity='%s'" % entity.name)
