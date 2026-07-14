class_name NpcActionButton extends Button
## 右栏确认/覆盖按钮 — 双模式统一脚本
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

var _is_override_mode: bool = false

## ── 覆盖模式专用 ──
var _override_action_uuid: String = ""
var _npc_doc: NPCDocument = null
var _is_locked: bool = false
var _lock_reason: String = ""

@onready var _title_label: Label = $MarginContainer/VBoxContainer/Label
@onready var _desc_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/Label2
@onready var _feas_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/Label3
@onready var _cost_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/Label4
@onready var _output_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer2/Label5
@onready var _risk_label: RichTextLabel = $MarginContainer/VBoxContainer/Label6


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	Logging.info("NpcActionButton._ready: override_mode=%s" % str(_is_override_mode))


func _on_pressed() -> void:
	HoverPopupManager.dismiss_all()
	if _is_override_mode:
		_on_override_pressed()
	else:
		_on_default_pressed()


func _on_default_pressed() -> void:
	var selected_uuid := VolatileState.action_state.selected_sub_action_uuid
	Logging.info("NpcActionButton._on_default_pressed: selected_uuid='%s'" % selected_uuid)
	if selected_uuid.is_empty():
		EventBus.request_toast.emit("请先选择一个行动", 1)
		return
	SubActionExecutor.execute(selected_uuid, VolatileState.action_state)
	var sub_action: Action = Database.get_action(selected_uuid) as Action
	execution_completed.emit(GameEntity.new({"uuid": selected_uuid, "name": sub_action.name if sub_action else selected_uuid}))


func _on_override_pressed() -> void:
	if _is_locked:
		var reason := _lock_reason if not _lock_reason.is_empty() else "暂时无法执行此行动"
		EventBus.request_toast.emit(reason, 1)
		return
	if _override_action_uuid.is_empty():
		EventBus.request_toast.emit("行动数据异常", 1)
		return
	SubActionExecutor.execute(_override_action_uuid, VolatileState.action_state)
	var override_action: Action = Database.get_action(_override_action_uuid) as Action
	execution_completed.emit(GameEntity.new({"uuid": _override_action_uuid, "name": override_action.name if override_action else _override_action_uuid}))


## ── 默认模式 ──

func set_placeholder(label_text: String = "") -> void:
	text = label_text


## 设置默认模式的行动数据。
## @param entity: 可选的 GameEntity（传递 MainActionButton 注入的锁定元数据、operators meta）
func set_action_data(action_name: String, action_uuid: String, entity = null) -> void:
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
	var simple_hint = _ActionHintBuilder.build_sub_action_preview(action, success_ops, fail_ops, 0.0, _HintProfile.Profile.SIMPLE)
	var default_hint = _ActionHintBuilder.build_sub_action_preview(action, success_ops, fail_ops, 0.0, _HintProfile.Profile.DEFAULT)

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

	_is_locked = NpcActionLockChecker.is_locked(override_action_uuid, npc_doc)
	if _is_locked:
		_lock_reason = NpcActionLockChecker.get_lock_reason(override_action_uuid, npc_doc)
		_set_gray_visual(true)
	else:
		_set_gray_visual(false)

	# 🆕 使用 build_sub_action_preview：SIMPLE → labels, DEFAULT → hover
	# cost 由 ActionHintFormatter 内部自动收集
	var succ_arch = Database.get_archetype_by_uuid(override_action_uuid, "success")
	var success_ops: Array = succ_arch.operators.duplicate(true) if succ_arch else []
	var fail_arch = Database.get_archetype_by_uuid(override_action_uuid, "failure")
	var fail_ops: Array = fail_arch.operators.duplicate(true) if fail_arch else []
	var simple_hint = _ActionHintBuilder.build_sub_action_preview(override_action, success_ops, fail_ops, 0.0, _HintProfile.Profile.SIMPLE)
	var default_hint = _ActionHintBuilder.build_sub_action_preview(override_action, success_ops, fail_ops, 0.0, _HintProfile.Profile.DEFAULT)

	_populate_labels_from_hint(simple_hint, _is_locked, _lock_reason)
	_register_hover_from_action_hint(default_hint)
	Logging.info("NpcActionButton.bind: override action='%s' SIMPLE→labels, DEFAULT→hover" % action_name)


## ════════════════════════════════════════════════════════════════
## 🆕 Label / Hover 填充（基于 ActionHint 结构化对象）
## ════════════════════════════════════════════════════════════════

## 从 ActionHint (SIMPLE profile) 提取模块行填充 label 控件。
## @param locked: true 时展示锁定视图（可行性不足 + 锁定原因）
## @param lock_reason: 锁定原因文本（如 "缺银两" 等）
func _populate_labels_from_hint(hint, locked: bool, lock_reason: String) -> void:
	if locked:
		_set_label(_feas_label, "可行性：不足")
		_set_label(_cost_label, "耗费：—")
		_set_label(_output_label, "产出：—")
		_set_label(_risk_label, "锁定：" + (lock_reason if not lock_reason.is_empty() else "条件不足"))
		Logging.info("NpcActionButton._populate_labels_from_hint: locked mode, reason='%s'" % lock_reason)
		return

	# ── 可行性：取 feas 模块首行（若有）──
	if hint.feasibility and not hint.feasibility.lines.is_empty():
		_set_label(_feas_label, hint.feasibility.lines[0])
	else:
		_set_label(_feas_label, "可行性：未知")

	# ── 耗费 ──
	var cost_text := _module_lines_joined(hint.cost)
	_set_label(_cost_label, "耗费：" + cost_text if not cost_text.is_empty() else "耗费：无")

	# ── 产出 ──
	var output_text := _module_lines_joined(hint.output)
	_set_label(_output_label, "产出：" + output_text if not output_text.is_empty() else "产出：无")

	# ── 风险 ──
	var risk_text := _module_lines_joined(hint.risk)
	_set_label(_risk_label, "风险：" + risk_text if not risk_text.is_empty() else "风险：无")

	Logging.info("NpcActionButton._populate_labels_from_hint: SIMPLE labels populated")


## 从 ActionHint (DEFAULT profile) 提取 narrative + vector 并注册到 HoverPopupManager
func _register_hover_from_action_hint(hint) -> void:
	HoverPopupManager.unregister(self)

	if not hint:
		Logging.warn("NpcActionButton._register_hover_from_action_hint: hint 为空，跳过")
		return

	var narrative: String = hint.narrative if not hint.narrative.is_empty() else ""
	var vector: String = hint.vector if not hint.vector.is_empty() else ""

	if narrative.is_empty() and vector.is_empty():
		Logging.info("NpcActionButton._register_hover_from_action_hint: narrative + vector 均为空，跳过注册")
		return

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
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


func _set_gray_visual(gray: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.6) if gray else Color.WHITE
	disabled = false


## 节点从场景树移除时注销 hover 绑定
func _exit_tree() -> void:
	HoverPopupManager.unregister(self)
	Logging.info("NpcActionButton._exit_tree: 已注销 hover 绑定")
