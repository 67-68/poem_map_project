class_name NpcActionButton extends PanelContainer
## 右栏确认/覆盖按钮 — 双模式统一脚本
## 根节点 PanelContainer（视觉容器），内部透明 Button 代理交互事件
##
## 默认模式（_is_override_mode = false）：
##   set_action_data(name, uuid, [entity]) → 标题 + description + SIMPLE profile 四模块 + 锁定提示
##   点击 → 读 VolatileState.selected_sub_action_uuid → SubActionExecutor.execute()
##
## 覆盖模式（_is_override_mode = true）：
##   bind(npc_doc, override_uuid) → 标题 + "NPC提供：{name}" + SIMPLE profile 四模块 + 锁定判定
##   点击 → 锁定 toast / SubActionExecutor.execute(override_uuid)
##
## 🆕 按钮 label 内容使用 ActionHintBuilder SIMPLE profile，hover 使用 DEFAULT profile

signal execution_completed(entity: GameEntity)

const _ActionHintBuilder = preload("res://core/action_hint_builder.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")
const _STYLE_FLAT = preload("res://ui/npc_btn_flat.tres")
const _STYLE_HOVERED = preload("res://ui/npc_btn_hovered.tres")

var _is_override_mode: bool = false

## ── 覆盖模式专用 ──
var _override_action_uuid: String = ""
var _npc_doc: NPCDocument = null
var _is_locked: bool = false
var _lock_reason: String = ""

## 🐛 默认模式锁定检查 — 保存 set_action_data 传入的 entity 引用
var _entity: GameEntity = null

@onready var _inner_button: Button = $Button
@onready var _title_label: Label = $Button/MarginContainer/VBoxContainer/Label
@onready var _desc_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer/Label2
@onready var _feas_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer/Label3
@onready var _cost_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer2/Label4
@onready var _output_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer2/Label5
@onready var _req_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer3/Label4
@onready var _risk_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/HBoxContainer3/Label6
@onready var _lock_reason_label: RichTextLabel = $Button/MarginContainer/VBoxContainer/LockReason
@onready var _hbox1: HBoxContainer = $Button/MarginContainer/VBoxContainer/HBoxContainer
@onready var _hbox2: HBoxContainer = $Button/MarginContainer/VBoxContainer/HBoxContainer2
@onready var _hbox3: HBoxContainer = $Button/MarginContainer/VBoxContainer/HBoxContainer3


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if _inner_button:
		if not _inner_button.pressed.is_connected(_on_pressed):
			_inner_button.pressed.connect(_on_pressed)
		if not _inner_button.mouse_entered.is_connected(_on_hover_enter):
			_inner_button.mouse_entered.connect(_on_hover_enter)
		if not _inner_button.mouse_exited.is_connected(_on_hover_exit):
			_inner_button.mouse_exited.connect(_on_hover_exit)
	Logging.info("NpcActionButton._ready: override_mode=%s" % str(_is_override_mode))


func _on_pressed() -> void:
	HoverPopupManager.dismiss_all()
	if _is_override_mode:
		_on_override_pressed()
	else:
		_on_default_pressed()


## ── Hover 样式切换 ──

func _on_hover_enter() -> void:
	add_theme_stylebox_override("panel", _STYLE_HOVERED)
	Logging.info("NpcActionButton._on_hover_enter: stylebox → hovered")


func _on_hover_exit() -> void:
	add_theme_stylebox_override("panel", _STYLE_FLAT)
	Logging.info("NpcActionButton._on_hover_exit: stylebox → flat")


func _on_default_pressed() -> void:
	# 🆕 锁定态检查前置 — 即使没有 selected_uuid，如果 entity 锁定也要 toast 原因
	if _entity and _entity.get_meta("_is_locked", false):
		var reason: String = _entity.get_meta("_locked_reason", "")
		if reason.is_empty():
			reason = tr("CODE_NPC_ACTION_BUTTON_60ABF5AC4F")
		EventBus.request_toast.emit(reason, 1)
		Logging.info("NpcActionButton._on_default_pressed: 锁定态点击被拦截, entity='%s', reason='%s'" % [_entity.name if _entity else "null", reason])
		return

	var selected_uuid := VolatileState.action_state.selected_sub_action_uuid
	Logging.info("NpcActionButton._on_default_pressed: [地点DEBUG] selected_uuid='%s', stay_place='%s', place_mismatch=%s, required_place='%s'" % [
		selected_uuid, PlayerState.stay_place,
		str(VolatileState.action_state.selected_entity_place_mismatch),
		VolatileState.action_state.selected_entity_required_place
	])
	if selected_uuid.is_empty():
		EventBus.request_toast.emit(tr("CODE_NPC_ACTION_BUTTON_B7F447C362"), 1)
		return
	Logging.info("NpcActionButton._on_default_pressed: [地点DEBUG] 即将执行 SubActionExecutor, stay_place='%s'" % PlayerState.stay_place)
	SubActionExecutor.execute(selected_uuid, VolatileState.action_state)
	Logging.info("NpcActionButton._on_default_pressed: [地点DEBUG] SubActionExecutor 返回后 stay_place='%s'" % PlayerState.stay_place)
	var sub_action: Action = Database.get_action(selected_uuid) as Action
	execution_completed.emit(GameEntity.new({"uuid": selected_uuid, "name": sub_action.name if sub_action else selected_uuid}))


func _on_override_pressed() -> void:
	if _is_locked:
		var reason := _lock_reason if not _lock_reason.is_empty() else tr("CODE_NPC_ACTION_BUTTON_60ABF5AC4F")
		EventBus.request_toast.emit(reason, 1)
		return
	if _override_action_uuid.is_empty():
		EventBus.request_toast.emit(tr("CODE_NPC_ACTION_BUTTON_B5F6E16585"), 1)
		return
	SubActionExecutor.execute(_override_action_uuid, VolatileState.action_state)
	var override_action: Action = Database.get_action(_override_action_uuid) as Action
	execution_completed.emit(GameEntity.new({"uuid": _override_action_uuid, "name": override_action.name if override_action else _override_action_uuid}))


## ── 默认模式 ──

func set_placeholder(label_text: String = "") -> void:
	if _title_label:
		_title_label.text = label_text

## 🆕 锁定态专用 — 展示 LockReason label 并隐藏 HBoxContainer 1/2/3，按钮灰化
func set_action_data_for_locked(entity: GameEntity) -> void:
	_entity = entity
	var reason: String = entity.get_meta("_locked_reason", "")
	if reason.is_empty():
		reason = entity.name if entity else tr("CODE_NPC_ACTION_BUTTON_60ABF5AC4F")
	# 标题保持 entity.name（不覆盖为锁因）
	if _title_label:
		_title_label.text = entity.name if entity else ""
	# 🆕 LockReason 显示锁因
	if _lock_reason_label:
		_lock_reason_label.text = "[color=#cc6666]🔒 %s[/color]" % reason
		_lock_reason_label.visible = true
	# 🆕 隐藏三个 HBoxContainer（而非清空内部 label）
	if _hbox1:
		_hbox1.visible = false
	if _hbox2:
		_hbox2.visible = false
	if _hbox3:
		_hbox3.visible = false
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	if _inner_button:
		_inner_button.disabled = true
	HoverPopupManager.unregister(_inner_button)
	Logging.info("NpcActionButton.set_action_data_for_locked: entity='%s' reason='%s' (LockReason visible, hbox1/2/3 hidden)" % [entity.name if entity else "null", reason])


## 设置默认模式的行动数据。
## @param entity: 可选的 GameEntity（传递 MainActionButton 注入的锁定元数据、operators meta）
func set_action_data(action_name: String, action_uuid: String, entity = null) -> void:
	# 🐛 修复：保存 entity 引用用于 _on_default_pressed 锁定检查
	_entity = entity if entity else null

	# 🆕 恢复正常 visual（从 set_action_data_for_locked 灰化态恢复）
	modulate = Color.WHITE
	if _inner_button:
		_inner_button.disabled = false
	# 🆕 恢复正常态：隐藏 LockReason，显示三个 HBoxContainer
	if _lock_reason_label:
		_lock_reason_label.visible = false
	if _hbox1:
		_hbox1.visible = true
	if _hbox2:
		_hbox2.visible = true
	if _hbox3:
		_hbox3.visible = true

	if _title_label:
		_title_label.text = action_name

	var action: Action = Database.get_action(action_uuid) as Action

	# ── Label2: action.description ──
	if _desc_label:
		_desc_label.text = action.description if action and not action.description.is_empty() else action_name

	if not action:
		Logging.err("NpcActionButton.set_action_data: Database.get_action('%s') 返回 null" % action_uuid)
		return

	var is_locked: bool = entity.get_meta("_is_locked", false) if entity else false

	# 🆕 收集 archetype operators（与 MainActionButton 一致：success / failure）
	# cost 由 ActionHintFormatter 内部自动收集
	var succ_arch = Database.get_archetype_by_uuid(action_uuid, "success")
	var success_ops: Array = succ_arch.operators.duplicate(true) if succ_arch else []
	var fail_arch = Database.get_archetype_by_uuid(action_uuid, "failure")
	var fail_ops: Array = fail_arch.operators.duplicate(true) if fail_arch else []

	# 🆕 使用 build_sub_action_preview：SIMPLE → labels, DEFAULT → hover
	var simple_hint = _ActionHintBuilder.new().build_sub_action_preview(action, success_ops, fail_ops, 0.0, _HintProfile.Profile.SIMPLE, is_locked, entity.get_meta("_locked_reason", "") if entity else "")
	var default_hint = _ActionHintBuilder.new().build_sub_action_preview(action, success_ops, fail_ops, 0.0, _HintProfile.Profile.DEFAULT)

	if is_locked:
		_populate_labels_from_hint(simple_hint, true, entity.get_meta("_locked_reason", "") if entity else "")
	else:
		_populate_labels_from_hint(simple_hint, false, "")

	_register_hover_from_action_hint(default_hint)
	Logging.info("NpcActionButton.set_action_data: action='%s' SIMPLE→labels, DEFAULT→hover" % action_name)


## ── 覆盖模式 ──

func bind(npc_doc: NPCDocument, override_action_uuid: String) -> void:
	_is_override_mode = true
	_npc_doc = npc_doc
	_override_action_uuid = override_action_uuid

	# 🆕 覆盖模式正常态：隐藏 LockReason，显示三个 HBoxContainer
	if _lock_reason_label:
		_lock_reason_label.visible = false
	if _hbox1:
		_hbox1.visible = true
	if _hbox2:
		_hbox2.visible = true
	if _hbox3:
		_hbox3.visible = true

	var override_action: Action = Database.get_action(override_action_uuid) as Action
	var action_name := override_action.name if override_action else override_action_uuid
	var npc_name := npc_doc.name if not npc_doc.name.is_empty() else npc_doc.uuid

	if _title_label:
		_title_label.text = action_name

	# ── Label2: action.description ──
	if _desc_label:
		if override_action and not override_action.description.is_empty():
			_desc_label.text = override_action.description
		else:
			_desc_label.text = action_name

	# ── 锁定判定 1: NPC 相识度 ──
	_is_locked = NpcActionLockChecker.is_locked(override_action_uuid, npc_doc)
	if _is_locked:
		_lock_reason = NpcActionLockChecker.get_lock_reason(override_action_uuid, npc_doc)
		_set_gray_visual(true)
		# 🆕 覆盖模式锁定态：显示 LockReason，隐藏 HBoxContainer
		_show_lock_reason(_lock_reason)
		# 不再继续检查后续条件（NPC 相识度不足已锁定）
	else:
		# ── 锁定判定 2: Action requirements（PoemRequirement / TraitRequirement 等）──
		if override_action and override_action.aciton_requirements and not override_action.aciton_requirements.is_empty():
			for req in override_action.aciton_requirements:
				if req is PoemRequirement or req is TraitRequirement:
					if not req.compare(PlayerState):
						_is_locked = true
						if req is PoemRequirement:
							_lock_reason = tr("CODE_NPC_ACTION_BUTTON_50E9C6E262")
						elif req is TraitRequirement:
							var desc := req.describe_requirement() if req.has_method("describe_requirement") else tr("CODE_NPC_ACTION_BUTTON_021C2B38D2")
							_lock_reason = desc
						_set_gray_visual(true)
						# 🆕 覆盖模式锁定态：显示 LockReason，隐藏 HBoxContainer
						_show_lock_reason(_lock_reason)
						Logging.info("NpcActionButton.bind: override '%s' — requirement type='%s' not met → locked, reason='%s'" % [action_name, req.get_script().resource_path.get_file() if req.get_script() else "unknown", _lock_reason])
						break
		if not _is_locked:
			_set_gray_visual(false)

	# 🆕 使用 build_sub_action_preview：SIMPLE → labels, DEFAULT → hover
	# cost 由 ActionHintFormatter 内部自动收集
	var succ_arch = Database.get_archetype_by_uuid(override_action_uuid, "success")
	var success_ops: Array = succ_arch.operators.duplicate(true) if succ_arch else []
	var fail_arch = Database.get_archetype_by_uuid(override_action_uuid, "failure")
	var fail_ops: Array = fail_arch.operators.duplicate(true) if fail_arch else []
	var simple_hint = _ActionHintBuilder.new().build_sub_action_preview(override_action, success_ops, fail_ops, 0.0, _HintProfile.Profile.SIMPLE, _is_locked, _lock_reason)
	var default_hint = _ActionHintBuilder.new().build_sub_action_preview(override_action, success_ops, fail_ops, 0.0, _HintProfile.Profile.DEFAULT)

	_populate_labels_from_hint(simple_hint, _is_locked, _lock_reason)
	_register_hover_from_action_hint(default_hint)
	Logging.info("NpcActionButton.bind: override action='%s' SIMPLE→labels, DEFAULT→hover" % action_name)


## ════════════════════════════════════════════════════════════════
## 🆕 Label / Hover 填充（基于 ActionHint 结构化对象）
## ════════════════════════════════════════════════════════════════

## 从 ActionHint (SIMPLE profile) 提取模块行填充 label 控件。
## @param locked: 当前未使用，保留签名兼容
## @param lock_reason: 当前未使用，保留签名兼容
func _populate_labels_from_hint(hint, locked: bool, lock_reason: String) -> void:
	var labels: Dictionary = hint.simple_labels if hint else {}
	_set_label(_feas_label, labels.get("feasibility", tr("CODE_NPC_ACTION_BUTTON_7005AA9069")))
	_set_label(_cost_label, labels.get("cost", tr("CODE_NPC_ACTION_BUTTON_7CA5205A5B")))
	_set_label(_output_label, labels.get("output", tr("CODE_NPC_ACTION_BUTTON_0F9928F317")))

	# 🆕 requirements — 空字符串时隐藏 label
	var req_text: String = labels.get("requirements", "")
	if req_text.is_empty():
		_set_label(_req_label, "")
		if _req_label:
			_req_label.visible = false
	else:
		_set_label(_req_label, req_text)
		if _req_label:
			_req_label.visible = true

	_set_label(_risk_label, labels.get("risk", tr("CODE_NPC_ACTION_BUTTON_4D7C36AA23")))
	Logging.info("NpcActionButton._populate_labels_from_hint: labels=%s" % str(labels))


## 从 ActionHint (DEFAULT profile) 提取 narrative + vector 并注册到 HoverPopupManager
func _register_hover_from_action_hint(hint) -> void:
	HoverPopupManager.unregister(_inner_button)

	if not hint:
		Logging.warn("NpcActionButton._register_hover_from_action_hint: hint 为空，跳过")
		return

	var narrative: String = hint.narrative if not hint.narrative.is_empty() else ""
	var vector: String = hint.vector if not hint.vector.is_empty() else ""

	if narrative.is_empty() and vector.is_empty():
		Logging.info("NpcActionButton._register_hover_from_action_hint: narrative + vector 均为空，跳过注册")
		return

	HoverPopupManager.register(_inner_button, {"narrative": narrative, "vector": vector}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("NpcActionButton._register_hover_from_action_hint: hover 注册完成 (BELOW_OVERLAY, DEFAULT profile), mode=%s" % ("override" if _is_override_mode else "default"))


## 将 ActionHintModule 的行用 "、" 拼接成一行文本
static func _module_lines_joined(mod) -> String:
	if not mod or mod.lines.is_empty():
		return ""
	return "、".join(mod.lines)


## 写入 Label 文本
static func _set_label(label_node: RichTextLabel, text: String) -> void:
	if label_node:
		label_node.text = text


## 🆕 锁定态通用辅助：显示 LockReason label 并隐藏 HBoxContainer 1/2/3
func _show_lock_reason(reason: String) -> void:
	if _lock_reason_label:
		_lock_reason_label.text = "[color=#cc6666]🔒 %s[/color]" % reason
		_lock_reason_label.visible = true
	if _hbox1:
		_hbox1.visible = false
	if _hbox2:
		_hbox2.visible = false
	if _hbox3:
		_hbox3.visible = false
	Logging.info("NpcActionButton._show_lock_reason: reason='%s' (LockReason visible, hbox1/2/3 hidden)" % reason)


func _set_gray_visual(gray: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.6) if gray else Color.WHITE
	if _inner_button:
		_inner_button.disabled = false


## 节点从场景树移除时注销 hover 绑定
func _exit_tree() -> void:
	HoverPopupManager.unregister(_inner_button)
	Logging.info("NpcActionButton._exit_tree: 已注销 hover 绑定")
