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

signal execution_completed(entity: GameEntity)

## 可行性三级文字映射（基于 named_amounts 中的 key）
const _FEASIBILITY_LABELS = {
	"l_success_rate": "可行性：高",
	"m_success_rate": "可行性：中",
	"s_success_rate": "可行性：低",
	"ms_success_rate": "可行性：可能",
	"xs_success_rate": "可行性：渺茫",
	"xxs_success_rate": "可行性：极低",
}

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
## @param entity: 可选的 GameEntity（传递 MainActionButton 注入的锁定元数据）
func set_action_data(action_name: String, action_uuid: String, entity = null) -> void:
	if _title_label:
		_title_label.text = action_name

	var action: Action = Database.get_action(action_uuid) as Action

	# ── Label2: action.description ──
	if _desc_label:
		_desc_label.text = action.description if action and not action.description.is_empty() else action_name

	if action:
		if entity and entity.get_meta("_is_locked", false):
			_build_locked_hint(entity, action)
		else:
			_populate_hint_modules(action)
	else:
		Logging.err("NpcActionButton.set_action_data: Database.get_action('%s') 返回 null" % action_uuid)

	# 🆕 注册 hover popup（右侧按钮 hover 展示行动效果）
	_register_hover_from_labels()


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

	_populate_hint_modules(override_action)

	_is_locked = NpcActionLockChecker.is_locked(override_action_uuid, npc_doc)
	if _is_locked:
		_lock_reason = NpcActionLockChecker.get_lock_reason(override_action_uuid, npc_doc)
		_set_gray_visual(true)
	else:
		_set_gray_visual(false)

	# 🆕 注册 hover popup（右侧覆盖按钮 hover 展示行动效果）
	_register_hover_from_labels()


## ════════════════════════════════════════════════════════════════
## SIMPLE hint 构建（非 SceneAction 通用）
## ════════════════════════════════════════════════════════════════

func _populate_hint_modules(action: Action) -> void:
	if action == null:
		Logging.err("NpcActionButton._populate_hint_modules: action 为空")
		return

	# ── 可行性：用 possibility key 查三级文字 ──
	var feas_text = _FEASIBILITY_LABELS.get(action.possibility, "可行性：未知")
	_set_label(_feas_label, feas_text)

	# ── 耗费：时间 + cost archetype ──
	var cost_parts: Array[String] = []
	if action.day_consumed > 0:
		cost_parts.append("⏱" + ActionManager.format_time_detail(action.day_consumed))
	var cost_ops := action.get_cost_operators() if action.has_method("get_cost_operators") else []
	for op in cost_ops:
		if op is PropertyOperator:
			var pop = op as PropertyOperator
			if pop.property.is_empty() or pop.value == 0:
				continue
			var prop = Database.get_property(pop.property)
			var pname = prop.get_display_name() if prop else pop.property
			var cost_desc := "%s %s" % [pname, str(abs(pop.value))]
			cost_parts.append(cost_desc)
	_set_label(_cost_label, "耗费：" + "、".join(cost_parts) if not cost_parts.is_empty() else "耗费：无")

	# ── 产出：success archetype ──
	var output_parts: Array[String] = []
	var success_ops: Array = action.get_all_action_results() if action.has_method("get_all_action_results") else []
	if success_ops.is_empty():
		var arch = Database.get_archetype_by_uuid(action.uuid, "success")
		if arch != null and not arch.operators.is_empty():
			success_ops = arch.operators.duplicate(true)
	for op in success_ops:
		if op is PropertyOperator:
			var pop = op as PropertyOperator
			if pop.value == 0 or pop.property.is_empty():
				continue
			var prop = Database.get_property(pop.property)
			var pname = prop.get_display_name() if prop else pop.property
			var arrow = "↑" if pop.value > 0 else "↓"
			output_parts.append("%s%s" % [pname, arrow])
	_set_label(_output_label, "产出：" + "、".join(output_parts) if not output_parts.is_empty() else "产出：无")

	# ── 风险：failed_result ──
	var risk_parts: Array[String] = []
	if action.failed_result and not action.failed_result.operators.is_empty():
		for op in action.failed_result.operators:
			if op is PropertyOperator:
				var pop = op as PropertyOperator
				if pop.value == 0 or pop.property.is_empty():
					continue
				var prop = Database.get_property(pop.property)
				var pname = prop.get_display_name() if prop else pop.property
				var arrow = "↑" if pop.value > 0 else "↓"
				risk_parts.append("%s%s" % [pname, arrow])
	_set_label(_risk_label, "风险：" + "、".join(risk_parts) if not risk_parts.is_empty() else "风险：无")


## 当 sub-action 被锁定（条件不足）时，用简明格式展示锁定原因
func _build_locked_hint(entity, action: Action) -> void:
	# ── 可行性：锁定 → 不可用 ──
	_set_label(_feas_label, "可行性：不足")

	# ── 耗费/产出/风险 → 从元数据中提取锁定原因 ──
	var locked_reason: String = entity.get_meta("_locked_reason", "")
	var reasons: Array[String] = []

	# 提取各类型需求描述
	if action and action.aciton_requirements:
		for req in action.aciton_requirements:
			if req is PropertyRequirement:
				var pop = req as PropertyRequirement
				var prop = Database.get_property(pop.property)
				var pname = prop.get_display_name() if prop else pop.property
				reasons.append("缺" + pname)
			elif req is NarrativeLockRequirement:
				reasons.append("不可抗力")

	# 时间不足检测：从 locked_reason 文本倒推
	if "时间" in locked_reason:
		reasons.append("缺时")

	if reasons.is_empty():
		reasons.append("条件不足")

	_set_label(_cost_label, "耗费：—")
	_set_label(_output_label, "产出：—")
	_set_label(_risk_label, "锁定：" + "、".join(reasons))


## 写入 Label 文本
static func _set_label(label_node: RichTextLabel, text: String) -> void:
	if label_node:
		label_node.text = text


func _set_gray_visual(gray: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.6) if gray else Color.WHITE
	disabled = false


## 🆕 从已填充的 label 模块提取文本，注册 hover popup（右侧按钮 hover 展示行动效果）
func _register_hover_from_labels() -> void:
	HoverPopupManager.unregister(self)

	var parts: Array[String] = []
	if _title_label and not _title_label.text.is_empty():
		parts.append("[b]" + _title_label.text + "[/b]")
	if _desc_label and not _desc_label.text.is_empty():
		parts.append(_desc_label.text)
	if _feas_label and not _feas_label.text.is_empty():
		parts.append(_feas_label.text)
	if _cost_label and not _cost_label.text.is_empty():
		parts.append(_cost_label.text)
	if _output_label and not _output_label.text.is_empty():
		parts.append(_output_label.text)
	if _risk_label and not _risk_label.text.is_empty():
		parts.append(_risk_label.text)

	if parts.is_empty():
		Logging.info("NpcActionButton._register_hover_from_labels: 无文本内容，跳过注册")
		return

	var narrative := _title_label.text if _title_label else ""
	var vector := "\n".join(parts)

	HoverPopupManager.register(self, {"narrative": narrative, "vector": vector}, 0.2, 0.75, HoverPopupManager.FlowType.BELOW_OVERLAY)
	Logging.info("NpcActionButton._register_hover_from_labels: hover 注册完成 (BELOW_OVERLAY), mode=%s" % ("override" if _is_override_mode else "default"))


## 节点从场景树移除时注销 hover 绑定
func _exit_tree() -> void:
	HoverPopupManager.unregister(self)
	Logging.info("NpcActionButton._exit_tree: 已注销 hover 绑定")
