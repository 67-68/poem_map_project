class_name NpcActionButton extends Button
## 右栏确认/覆盖按钮 — 双模式统一脚本
##
## 默认模式（_is_override_mode = false）：
##   set_action_label(name) → 更新 Label 标题
##   _on_pressed() → 读 VolatileState.selected_sub_action_uuid → SubActionExecutor.execute()
##
## 覆盖模式（_is_override_mode = true）：
##   bind(npc_doc, override_uuid) → 标题 + "NPC提供：{name}" + SIMPLE profile 四模块 + 锁定判定
##   _on_pressed() → 锁定 toast / SubActionExecutor.execute(override_uuid)
##
## 共用 npc_action_button.tscn 的 6 Label 布局：
##   Label  — 行动名称
##   HBoxContainer:
##     Label2  — 描述 / "NPC提供：{NPC名}"
##     VSeparator
##     Label3  — 可行性
##   HBoxContainer2:
##     Label4  — 耗费
##     VSeparator2
##     Label5  — 产出
##   Label6 — 风险

signal execution_completed(entity: GameEntity)  ## 执行完成后发射（Picker 用此信号关闭自身）

const _HintFormatter = preload("res://core/hints/action_hint_formatter.gd")
const _HintContext = preload("res://core/hints/hint_context.gd")
const _HintProfile = preload("res://core/hints/hint_profile.gd")

## 是否为覆盖模式（true = NPC override 按钮）
var _is_override_mode: bool = false

## ── 覆盖模式专用 ──
var _override_action_uuid: String = ""
var _npc_doc: NPCDocument = null
var _is_locked: bool = false
var _lock_reason: String = ""

## scn Label 引用（与 npc_action_button.tscn 路径映射）
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
	Logging.info("NpcActionButton._ready: 已连接 pressed 信号, override_mode=%s" % str(_is_override_mode))


func _on_pressed() -> void:
	HoverPopupManager.dismiss_all()

	if _is_override_mode:
		_on_override_pressed()
	else:
		_on_default_pressed()


## 默认模式：执行 VolatileState 中选中的 sub-action
func _on_default_pressed() -> void:
	var selected_uuid := VolatileState.action_state.selected_sub_action_uuid
	Logging.info("NpcActionButton._on_default_pressed: selected_uuid='%s'" % selected_uuid)

	if selected_uuid.is_empty():
		EventBus.request_toast.emit("请先选择一个行动", 1)
		Logging.info("NpcActionButton: 未选择任何行动，toast 提示")
		return

	SubActionExecutor.execute(selected_uuid, VolatileState.action_state)

	var sub_action: Action = Database.get_action(selected_uuid) as Action
	var result_entity := GameEntity.new({"uuid": selected_uuid, "name": sub_action.name if sub_action else selected_uuid})
	execution_completed.emit(result_entity)


## 覆盖模式：锁定检查 → 执行覆盖行动
func _on_override_pressed() -> void:
	if _is_locked:
		var reason := _lock_reason if not _lock_reason.is_empty() else "暂时无法执行此行动"
		EventBus.request_toast.emit(reason, 1)
		Logging.info("NpcActionButton._on_override_pressed: 锁定态拦截 — reason='%s'" % reason)
		return

	if _override_action_uuid.is_empty():
		Logging.err("NpcActionButton._on_override_pressed: _override_action_uuid 为空")
		EventBus.request_toast.emit("行动数据异常", 1)
		return

	Logging.info("NpcActionButton._on_override_pressed: 执行覆盖行动 uuid='%s'" % _override_action_uuid)
	SubActionExecutor.execute(_override_action_uuid, VolatileState.action_state)

	var override_action: Action = Database.get_action(_override_action_uuid) as Action
	var result_entity := GameEntity.new({
		"uuid": _override_action_uuid,
		"name": override_action.name if override_action else _override_action_uuid
	})
	execution_completed.emit(result_entity)


## ── 默认模式：更新标题 + SIMPLE profile 四模块 ──

func set_placeholder(label_text: String = "") -> void:
	text = label_text
	Logging.info("NpcActionButton.set_placeholder: label='%s'" % label_text)


## 设置默认模式的行动数据：标题 + 行动名作描述 + SIMPLE profile 填充 Label3~Label6
func set_action_data(action_name: String, action_uuid: String) -> void:
	# ── 标题 ──
	if _title_label:
		_title_label.text = action_name
		Logging.info("NpcActionButton.set_action_data: title_label ← '%s'" % action_name)
	else:
		Logging.err("NpcActionButton.set_action_data: 找不到 Label 节点")

	# ── 描述：行动名 ──
	if _desc_label:
		_desc_label.text = action_name
		Logging.info("NpcActionButton.set_action_data: desc_label ← '%s'" % action_name)

	# ── SIMPLE profile ──
	var action: Action = Database.get_action(action_uuid) as Action
	if action:
		_populate_hint_modules(action)
	else:
		Logging.err("NpcActionButton.set_action_data: Database.get_action('%s') 返回 null" % action_uuid)


## ── 覆盖模式：绑定 NPC + 覆盖行动，SIMPLE profile 填充四模块 ──

func bind(npc_doc: NPCDocument, override_action_uuid: String) -> void:
	_is_override_mode = true
	_npc_doc = npc_doc
	_override_action_uuid = override_action_uuid

	var override_action: Action = Database.get_action(override_action_uuid) as Action
	var action_name := override_action.name if override_action else override_action_uuid
	var npc_name := npc_doc.name if not npc_doc.name.is_empty() else npc_doc.uuid

	# ── 标题：覆盖行动名称 ──
	if _title_label:
		_title_label.text = action_name
		Logging.info("NpcActionButton.bind: title_label ← '%s'" % action_name)

	# ── 描述：NPC 提供 ──
	if _desc_label:
		_desc_label.text = "NPC提供：" + npc_name
		Logging.info("NpcActionButton.bind: desc_label ← 'NPC提供：%s'" % npc_name)

	# ── SIMPLE profile 构建 hint ──
	_populate_hint_modules(override_action)

	# ── 锁定判定 ──
	_is_locked = NpcActionLockChecker.is_locked(override_action_uuid, npc_doc)
	if _is_locked:
		_lock_reason = NpcActionLockChecker.get_lock_reason(override_action_uuid, npc_doc)
		_set_gray_visual(true)
		Logging.info("NpcActionButton.bind: action='%s' npc='%s' → LOCKED reason='%s'" % [override_action_uuid, npc_name, _lock_reason])
	else:
		_set_gray_visual(false)
		Logging.info("NpcActionButton.bind: action='%s' npc='%s' → UNLOCKED" % [override_action_uuid, npc_name])


## 用 SIMPLE profile 构建预览文本并填充 Label3~Label6
## 对非 SceneAction（普通 Action）从 archetype 直接读取 operators
func _populate_hint_modules(action: Action) -> void:
	if action == null:
		Logging.err("NpcActionButton._populate_hint_modules: action 为空")
		return

	# ── 可行性：概率 ──
	var prob: int = action.get_possibility_int()
	_set_label_from_module(_feas_label, null, "概率：" + str(prob) + "%")

	# ── 耗费：时间 + cost archetype ──
	var cost_parts: Array[String] = []
	if action.day_consumed > 0:
		var cost_detail = ActionManager.format_time_detail(action.day_consumed)
		cost_parts.append("⏱" + cost_detail)
	# cost archetype
	var cost_ops := action.get_cost_operators() if action.has_method("get_cost_operators") else []
	if not cost_ops.is_empty():
		for op in cost_ops:
			var desc = ""
			if op is PropertyOperator:
				var pop = op as PropertyOperator
				var prop = Database.get_property(pop.property)
				var pname = prop.get_display_name() if prop else pop.property
				desc = "%s %s" % [pname, str(abs(pop.value))]
			if not desc.is_empty():
				cost_parts.append(desc)
	_set_label_from_module(_cost_label, null, "耗费：" + "、".join(cost_parts) if not cost_parts.is_empty() else "耗费")

	# ── 产出：success archetype operators ──
	var output_parts: Array[String] = []
	var success_ops: Array = action.get_all_action_results() if action.has_method("get_all_action_results") else []
	if success_ops.is_empty():
		var arch = Database.get_archetype_by_uuid(action.uuid, "success")
		if arch != null and not arch.operators.is_empty():
			success_ops = arch.operators.duplicate(true)
	if not success_ops.is_empty():
		for op in success_ops:
			if op is PropertyOperator:
				var pop = op as PropertyOperator
				if pop.value == 0 or pop.property.is_empty():
					continue
				var prop = Database.get_property(pop.property)
				var pname = prop.get_display_name() if prop else pop.property
				var arrow = "↑" if pop.value > 0 else "↓"
				output_parts.append("%s %s%s" % [pname, str(abs(pop.value)), arrow])
	_set_label_from_module(_output_label, null, "产出：" + "、".join(output_parts) if not output_parts.is_empty() else "产出")

	# ── 风险：failed_result operators ──
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
				risk_parts.append("%s %s%s" % [pname, str(abs(pop.value)), arrow])
	_set_label_from_module(_risk_label, null, "风险：" + "、".join(risk_parts) if not risk_parts.is_empty() else "风险")

	Logging.info("NpcActionButton._populate_hint_modules: done for '%s' (prob=%d, cost=%d, output=%d, risk=%d)" % [
		action.name, prob, cost_parts.size(), output_parts.size(), risk_parts.size()])


## 将文本写入 Label，module 参数保留兼容性。
static func _set_label_from_module(label_node: RichTextLabel, module = null, fallback: String = "") -> void:
	if label_node == null:
		return
	label_node.text = fallback


func _set_gray_visual(gray: bool) -> void:
	if gray:
		modulate = Color(0.5, 0.5, 0.5, 0.6)
		disabled = false
	else:
		modulate = Color.WHITE
		disabled = false
