class_name SubActionButton extends SceneActionPanel
## 子行动选择器 — Toggle Mode 纯选择按钮
##
## 覆写 _on_clicked()：点击仅在 VolatileState 中写入 selected_sub_action_uuid
## 使用 Toggle Mode（toggle_mode = true），ButtonGroup 由 PickerTapeAttachment 管理以实现互斥。
##
## 不执行任何业务逻辑 — 真正的执行由 NpcActionButton 触发 SubActionExecutor。

var entity: GameEntity = null  ## 绑定的子行动 entity


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 直接绑定 pressed → 绕过基类 _on_button_pressed 的 defer/lock/Decision 检查
	if not pressed.is_connected(_on_sub_button_pressed):
		pressed.connect(_on_sub_button_pressed)
	Logging.info("SubActionButton._ready: entity='%s'" % (entity.name if entity else "null"))


func _on_sub_button_pressed() -> void:
	# 跳过基类 _on_button_pressed 的 defer/lock/Decision 逻辑
	# SubActionButton 仅做选择，无 action 对象
	HoverPopupManager.dismiss_all()
	_on_clicked()


## 绑定 entity（不传 Action，传 GameEntity）
func bind_entity(ent: GameEntity) -> void:
	entity = ent
	if not entity:
		Logging.warn("SubActionButton.bind_entity: entity 为空")
		return
	$Panel/HBoxContainer/VBoxContainer/Title.text = entity.name
	$Panel/HBoxContainer/VBoxContainer/Outcome.text = entity.description if entity.description else ""
	
	# icon: 从 meta 读取（MainActionButton 构建 entity 时注入）
	var icon = ent.get_meta("_action_icon", null)
	if icon:
		$Panel/HBoxContainer/TextureRect.texture = icon
		$Panel/HBoxContainer/TextureRect.visible = true
	else:
		$Panel/HBoxContainer/TextureRect.visible = false
	
	# 从 entity meta 读取锁定状态
	var meta_locked: bool = entity.get_meta("_is_locked", false)
	var meta_reason: String = entity.get_meta("_locked_reason", "")
	if meta_locked:
		set_locked(meta_reason)
		Logging.info("SubActionButton.bind_entity: entity='%s' 锁定态, reason='%s'" % [entity.name, meta_reason])
	
	Logging.info("SubActionButton.bind_entity: entity='%s' (hover 已迁移至右栏 NpcActionButton)" % entity.name)


func _on_clicked() -> void:
	Logging.info("SubActionButton._on_clicked: entity='%s' uuid=%s _is_locked=%s" % [
		entity.name if entity else "null",
		entity.uuid if entity else "null",
		str(_is_locked)
	])
	
	# ── 锁定态 → toast 不写入 ──
	if _is_locked:
		var toast_reason = entity.get_meta("_locked_reason", "") if entity else ""
		if toast_reason.is_empty():
			toast_reason = "暂时无法选择此行动"
		EventBus.request_toast.emit(toast_reason, 1)
		Logging.info("SubActionButton: 锁定态点击被拦截, entity='%s', reason='%s'" % [entity.name if entity else "null", toast_reason])
		return
	
	if not entity:
		Logging.warn("SubActionButton._on_clicked: entity 为空")
		return
	
	# ── 写入 VolatileState ──
	VolatileState.action_state.selected_sub_action_uuid = entity.uuid
	VolatileState.action_state.selected_entity_place_mismatch = entity.get_meta("_place_mismatch", false)
	VolatileState.action_state.selected_entity_required_place = entity.get_meta("_required_place", "")
	VolatileState.action_state.selected_entity_required_place_name = entity.get_meta("_required_place_name", "")
	Logging.info("SubActionButton._on_clicked: 写入 selected_sub_action_uuid='%s' place_mismatch=%s required_place='%s'" % [entity.uuid, str(VolatileState.action_state.selected_entity_place_mismatch), VolatileState.action_state.selected_entity_required_place_name])


## 覆写基类 _register_hover_popup — hover 已迁移至右栏 NpcActionButton，此处不注册
func _register_hover_popup() -> void:
	Logging.info("SubActionButton._register_hover_popup: hover 已迁移至右栏，跳过注册")


## 覆写基类 _refresh_hover_popup — hover 已迁移至右栏 NpcActionButton，此处不注册
func _refresh_hover_popup() -> void:
	HoverPopupManager.unregister(self)
	Logging.info("SubActionButton._refresh_hover_popup: hover 已迁移至右栏，仅清理旧绑定，不重新注册")


## 使用 entity meta 中的 operators + sub_action_preview 注册 hover popup
func _register_hover_popup_for_entity() -> void:
	if not entity:
		Logging.warn("SubActionButton._register_hover_popup_for_entity: entity 为空，跳过")
		return
	var ops: Array = entity.get_meta("operators", [])
	var sub_action_preview: String = entity.get_meta("sub_action_preview", "")
	Logging.info("SubActionButton._register_hover_popup_for_entity: 获取到 %d 个 operators, sub_action_preview='%s'" % [ops.size(), "yes(%d chars)" % sub_action_preview.length() if not sub_action_preview.is_empty() else "no"])

	var vector_lines: Array[String] = []

	if not sub_action_preview.is_empty():
		vector_lines.append(sub_action_preview)
		Logging.info("SubActionButton._register_hover_popup_for_entity: sub_action_preview 非空，跳过 operators 独立展示")
	else:
		var op_lines := ActionHintBuilder.build_operator_preview(ops)
		vector_lines.append_array(op_lines)
		Logging.info("SubActionButton._register_hover_popup_for_entity: ActionHintBuilder 生成 %d 行 operator 描述" % op_lines.size())
	
	var vector_text := "\n".join(vector_lines)
	if vector_text.is_empty():
		Logging.info("SubActionButton._register_hover_popup_for_entity: vector_text 为空，跳过注册")
		return

	var narrative := entity.name
	if _is_locked and not entity.get_meta("_locked_reason", "").is_empty():
		narrative = "[color=#cc6666]🔒 %s[/color]\n\n%s" % [entity.get_meta("_locked_reason"), entity.name]
	if not entity.description.is_empty():
		narrative += "\n" + entity.description

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector_text}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("SubActionButton._register_hover_popup_for_entity: hover 注册完成 (BELOW_OVERLAY), entity='%s'" % entity.name)
