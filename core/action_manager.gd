extends Node
const _Action = preload("res://core/model/action.gd")
const _ActionArchetype = preload("res://core/model/action_archetype.gd")
const _Era = preload("res://core/model/era.gd")
const _ActionFocusController = preload("res://core/action_focus_controller.gd")
const _ActionSelector = preload("res://core/action_selector.gd")
const _Generator = preload("res://core/model/generator.gd")
const _MicroDSLParser = preload("res://parser/micro_dsl_parser.gd")
const _SceneAction = preload("res://core/model/scene_action.gd")
const _SceneActionPanel = preload("res://ui/action_button.gd")
const _NamedDSLParser = preload("res://parser/named_dsl_parser.gd")
const _SurvivalManager = preload("res://core/survival_manager.gd")
const _PropertyOperator = preload("res://core/model/property_operator.gd")
const _EventManager = preload("res://core/event_manager.gd")
const _ModifierConfig = preload("res://core/modifier_config.gd")
const _ModifierRegistry = preload("res://core/modifier_registry.gd")
const _TraitRequirement = preload("res://core/requirements/trait_requirement.gd")
const _FlagRequirement = preload("res://core/requirements/flag_requirement.gd")
const _NarrativeLockRequirement = preload("res://core/requirements/narrative_lock_requirement.gd")
const _PoemRequirement = preload("res://core/requirements/poem_requirement.gd")
const _PropertyRequirement = preload("res://core/property_requirement.gd")
const _PropRangeRequirement = preload("res://core/requirements/range_requirement.gd")
const _EmotionRequirement = preload("res://core/requirements/emotion_requirement.gd")
const _ConsumeOldestImaginaryOperator = preload("res://core/operators/consume_oldest_imaginary_operator.gd")
const _RemoteActionFilterManager = preload("res://core/remote_action_filter_manager.gd")

const MAX_PICK_COUNT: int = 6

## 每回合即时预留（抽取后清空）
var _reserved_action_ids: Array[String] = []

## 持久化锁定（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _locked_in_actions: Dictionary = {}

## 持久化阻塞（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _blocked_actions: Dictionary = {}

## 🆕 Tutorial 行动白名单：空数组 = 不过滤（正常模式），非空 = 只显示白名单内的 action_id
var _tutorial_whitelist: Array[String] = []

## 🆕 本轮已抽中的 action ID 集合（key=action_id, val=true）。
## 属性变动重评估时，已中签的 action 保留此标记，未中签的永远灰化。
var _selected_action_ids: Dictionary = {}

## 🆕 缓存 event_archetypes.json 中的 failed_hints 字段
## 结构: { archetype_key: { prop_name: narrative_text } }

## 🆕 是否已连接 player_stat_changed 信号（防重连）
var _stat_signal_connected: bool = false

## 🆕 批量模式守卫：行动执行期间抑制 reevaluate，全部 results 执行完后统一评估。
var _suppress_reevaluate: bool = false

## 🆕 缓存所有作为 sub_action 出现的 action uuid 集合（key=uuid, value=true）
var _all_sub_action_ids: Dictionary = {}

## 🆕 Focus session 控制器（不污染 _blocked_actions / _locked_in_actions）
var _focus_controller: _ActionFocusController

## 🆕 属性变动 debounce：同帧/相邻帧内的多次 stat change 只触发一次 reevaluate_all_locks
const STAT_DEBOUNCE_MS: float = 0.1  # 100ms 合并窗口
var _stat_debounce_timer: Timer = null
var _stat_debounce_pending: bool = false

## 🆕 活跃 defer 状态字典（key=action_id, val=Dictionary）。
## 结构: {
##   "remaining_xun": int,              # 剩余旬数
##   "used_resource_archetype": String, # Database.action_archetypes 的 key
##   "ap_cost": String,                 # named_amounts 的 key
##   "failed_fallback": String,         # 资源中断时推的事件 UUID
##   "main_tag": String,               # action 的 main_tag（到期扫描用）
## }
var _deferring_actions: Dictionary = {}

func _ready() -> void:
	_focus_controller = _ActionFocusController.new()
	_init_archetype_cache()
	connect_to_player_state()
	
	# 🆕 创建 debounce timer，one-shot 模式，同帧内多次 stat change 合并为一次 reevaluate
	_stat_debounce_timer = Timer.new()
	_stat_debounce_timer.one_shot = true
	_stat_debounce_timer.wait_time = STAT_DEBOUNCE_MS
	_stat_debounce_timer.timeout.connect(_on_stat_debounce_timeout)
	add_child(_stat_debounce_timer)


# ════════════════════════════════════════════════════════════
# Focus Session 查询（实际控制由 ActionFocusController 接管）
# ════════════════════════════════════════════════════════════

## 返回 focus 控制器引用。供 operator 和 button 调用时获取/通知。
func get_focus_controller() -> _ActionFocusController:
	return _focus_controller

## 查询当前是否处于 focus session 中。
func is_in_focus_session() -> bool:
	return _focus_controller.is_active()

## 获取当前 focus session 剩余点击次数（-1 表示不在 session 中）。
func get_focus_click_remaining() -> int:
	return _focus_controller.get_focus_click_remaining()


# ════════════════════════════════════════════════════════════
# 即时预留（每回合，抽取后清空）
# ════════════════════════════════════════════════════════════

## 预定一个 action，确保本回合必定被选中。
## 返回 true 表示预定成功，false 表示失败（见 push_error）。
func reserve_action(action_id: String) -> bool:
	# 1. 检查席位是否已满
	if _reserved_action_ids.size() >= MAX_PICK_COUNT:
		Logging.err("[ActionManager] 预留席位已满 (%d/%d)，预定失败: %s" % [MAX_PICK_COUNT, MAX_PICK_COUNT, action_id])
		push_error(tr("CODE_ACTION_MANAGER_3BB5410E85"))
		return false
	
	# 2. 检查是否重复预定
	if action_id in _reserved_action_ids:
		Logging.err("[ActionManager] action 已被重复预定: %s" % action_id)
		push_error(tr("CODE_ACTION_MANAGER_C1939F32EF"))
		return false
	
	_reserved_action_ids.append(action_id)
	Logging.info("[ActionManager] 预定成功: %s (当前 %d/%d)" % [action_id, _reserved_action_ids.size(), MAX_PICK_COUNT])
	return true


## 取消一个预留
func unreserve_action(action_id: String) -> void:
	_reserved_action_ids.erase(action_id)
	Logging.info("[ActionManager] 取消预留: %s" % action_id)


## 清除所有预定（每次抽取后自动调用）
func clear_reservations() -> void:
	_reserved_action_ids.clear()


# ════════════════════════════════════════════════════════════
# 🆕 行动锁定评估系统（纯函数 + 缓存 + 信号监听）
# ════════════════════════════════════════════════════════════

## 🆕 初始化 ActionArchetype 缓存。
## archetype .tres 文件由 DataScanner 自动加载到 Database（扫描 data/ 目录树）。
## 如果 Database 中的 archetypes 为空（例如在 @tool 模式或测试环境），
## 则尝试从 resource_converters.csv 运行时解析。
func _init_archetype_cache() -> void:
	if not Database.action_archetypes.is_empty():
		Logging.info("[ActionManager] DataScanner 已加载 %d 个 archetype, 跳过" % Database.action_archetypes.size())
		return

	Logging.info("[ActionManager] Database.action_archetypes 为空，尝试从 CSV 运行时解析")
	var save_path := "res://data/1_core_rules/resource_converters.csv"
	if not FileAccess.file_exists(save_path):
		Logging.warn("[ActionManager] resource_converters.csv 不存在，跳过")
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		Logging.warn("[ActionManager] 无法读取 resource_converters.csv")
		return
	var csv_str := file.get_as_text()
	file.close()

	# 从 CSV 运行时解析并保存到 Database（仅此一次）
	var csv_data := _csv_to_dicts(csv_str)
	if csv_data.is_empty():
		return

	# 调用 DSLParser 解析
	var all_resources := DSLParser._parse_resource_converter(csv_data)
	# 从返回的资源中提取 ActionArchetype 注册到 Database
	var arch_count := 0
	for res in all_resources:
		if res is ActionArchetype:
			var arch := res as ActionArchetype
			if not arch.uuid.is_empty():
				Database.action_archetypes[arch.uuid] = arch
				arch_count += 1
	Logging.info("[ActionManager] 运行时 fallback 加载了 %d 个 archetype" % arch_count)


## 简单 CSV 字符串 → Array[Dictionary]
func _csv_to_dicts(csv_str: String) -> Array[Dictionary]:
	var lines := csv_str.split("\n")
	if lines.size() < 2:
		return []
	var headers := lines[0].strip_edges().split(",")
	var result: Array[Dictionary] = []
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var values := _parse_csv_line(line)
		var row := {}
		for j in range(headers.size()):
			if j < values.size():
				var key := headers[j].strip_edges()
				var value := values[j].strip_edges()
				if value.begins_with("\"") and value.ends_with("\""):
					value = value.substr(1, value.length() - 2)
				row[key] = value
		if not row.is_empty():
			result.append(row)
	return result


## 简单 CSV 行解析（处理引号 + 括号深度）
func _parse_csv_line(line: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var in_quotes := false
	var paren_depth := 0

	for i in range(line.length()):
		var ch = line[i]
		if ch == "\"":
			in_quotes = not in_quotes
		elif ch == "," and not in_quotes and paren_depth == 0:
			result.append(current)
			current = ""
		else:
			current += ch
			if not in_quotes:
				if ch == "(":
					paren_depth += 1
				elif ch == ")":
					paren_depth -= 1

	result.append(current)
	return result


## 🆕 遍历所有 action，收集其 sub_actions 字段中的 uuid，存入 _all_sub_action_ids 字典。
func _collect_sub_action_ids() -> void:
	_all_sub_action_ids.clear()
	for a_id in Database.get_actions_all():
		var a = Database.get_action(a_id) as Action
		if a and not a.sub_actions.is_empty():
			for sub_id in a.sub_actions:
				_all_sub_action_ids[sub_id] = true


## 根据 action 的 _main_tag 查找对应的 archetype key。
## 例如 _main_tag=29(ACTION_MAIN_BAIYE) → action_tag_to_action_type(29)=0(BAI_YE) → "baiye"
func _get_archetype_key(action: Action) -> String:
	if not action is SceneAction:
		return ""
	var scene_action := action as SceneAction
	var main_tag_val := scene_action._main_tag
	var action_type := ENUMS.action_tag_to_action_type(main_tag_val)
	if action_type < 0:
		return ""
	var type_name = ENUMS.ACTION_TYPE.keys()[action_type]
	return type_name.to_lower().replace("_", "")


## 从 Database 加载的 ActionArchetype 中获取失败叙事文本。
func _get_archetype_failed_hint(action: Action, prop_name: String) -> String:
	var key := _get_archetype_key(action)
	if key.is_empty():
		return ""
	var archetype: ActionArchetype = Database.action_archetypes.get(key)
	if not archetype:
		return ""
	return archetype.failed_hints.get(prop_name, "")


## 🆕 解析 action 的 cost archetype（state="cost"），提取属性消耗 operators。
## 优先使用 action.uuid + "cost" 精确查找。
## 如果不存在，fallback 到旧的 action_type 映射方式。
func _parse_archetype_costs(action: Action) -> Array:
	var costs: Array = []
	if not action:
		return costs
	
	# 方式 1: 使用 action.uuid + "cost" 精确查找
	var cost_arch = Database.get_archetype_by_uuid(action.uuid, "cost")
	if cost_arch != null and not cost_arch.operators.is_empty():
		Logging.info("[ActionManager] _parse_archetype_costs: uuid='%s' 找到 cost archetype (%d ops)" % [action.uuid, cost_arch.operators.size()])
		for op in cost_arch.operators:
			costs.append(op)
		return costs
	
	# 方式 2: 旧的 action_type 映射方式（兼容没有 cost archetype 的旧 action）
	var key := _get_archetype_key(action)
	if key.is_empty():
		return costs
	var archetype: ActionArchetype = Database.action_archetypes.get(key)
	if not archetype:
		return costs
	for op in archetype.operators:
		costs.append(op)
	return costs


## 🆕 静态方法：检查一组 operators 中的属性消耗是否会让玩家属性跌破下限。
## 适用于主行动（archetype operators）和子行动（success/fail archetype operators）。
## @param operators: Array[BaseOperator] — 来自 archetype 的 operators
## @return Array[String] — 失败原因列表（空数组表示全部可通过）
func check_archetype_property_costs(operators: Array) -> Array[String]:
	var reasons: Array[String] = []
	if operators.is_empty():
		return reasons
	
	for op in operators:
		if not op is _PropertyOperator:
			continue
		var pop := op as _PropertyOperator
		if pop.value >= 0:
			continue  # 只检查消耗（负值），收益不拦截
		var prop_name: String = pop.property

		# 🆕 使用修饰符公式预估实际消耗（委托 ModifierRegistry 统一注册表查询）
		var raw_need: int = -pop.value  # 转为正数（需求值）
		var adjusted_delta: int = _ModifierRegistry.get_modifier_prop_adjusted_delta(prop_name, -raw_need)
		var adjusted_need: int = -adjusted_delta  # 转回正数比较

		var current_val = PlayerState.get_stat_val(prop_name)
		if current_val < adjusted_need:
			var prop_data = Database.get_property(prop_name)
			var prop_display_name = prop_data.get_display_name() if prop_data else prop_name
			var precise_line := tr("CODE_ACTION_MANAGER_14BEE7594A") % [prop_display_name, current_val, adjusted_need]
			reasons.append(precise_line)
			Logging.info("[ActionManager] check_archetype_property_costs: prop=%s current=%d raw_need=%d adjusted_need=%d → GRAY" % [prop_name, current_val, raw_need, adjusted_need])
		else:
			Logging.info("[ActionManager] check_archetype_property_costs: prop=%s current=%d raw_need=%d adjusted_need=%d → OK" % [prop_name, current_val, raw_need, adjusted_need])
	
	Logging.info("[ActionManager] check_archetype_property_costs: %d operators → %d reasons" % [operators.size(), reasons.size()])
	return reasons


# ════════════════════════════════════════════════════════════
# 🆕 父行动子行动可用性检查（轻量级预览版）
# ════════════════════════════════════════════════════════════

## 纯静态函数：遍历父行动的所有子行动，做轻量级 HIDE / GRAY 判定。
## 这是 MainActionButton._on_clicked() 完整判定的近似快速预览，仅用于决定父按钮是否提前灰化。
##
## Phase 0: prerequisite — HIDE
## Phase 1: TraitRequirement / FlagRequirement / NarrativeLockRequirement / ConsumeOldestImaginaryOperator — HIDE
## Phase 2: PropertyRequirement / EmotionRequirement / PropRangeRequirement / PoemRequirement / cost archetype 属性不足 / 时间不足 — GRAY
##
## @param action: 父 Action（必须含 sub_actions）
## @return {
##   "all_hidden": bool — 所有子行动均被 HIDE（Phase 0/1 全灭）
##   "all_gray": bool — 所有子行动均被 GRAY（Phase 2 全灰，至少一个可见但不可用）
##   "all_unavailable": bool — all_hidden || all_gray（任何全灭态）
##   "reasons": Array[String] — 汇总原因（每条对应一个子行动的状态描述）
## }
func check_parent_action_children_availability(action: Action) -> Dictionary:
	var result := {
		"all_hidden": false,
		"all_gray": false,
		"all_unavailable": false,
		"reasons": [],
	}
	
	if not action or action.sub_actions.is_empty():
		Logging.info("[ActionManager] check_parent_action_children_availability: action无子行动，跳过")
		return result
	
	var total_subs := action.sub_actions.size()
	var hidden_count := 0
	var gray_count := 0
	var available_count := 0
	
	for sub_uuid in action.sub_actions:
		if sub_uuid.is_empty():
			hidden_count += 1
			Logging.info("[ActionManager] check_parent_action_children_availability: 子行动 UUID为空 → HIDE")
			continue
		
		var sub_action: Action = Database.get_action(sub_uuid) as Action
		if not sub_action:
			hidden_count += 1
			result.reasons.append(tr("CODE_ACTION_MANAGER_6A45CE8F1B") % sub_uuid)
			Logging.warn("[ActionManager] check_parent_action_children_availability: 子行动 '%s' 无法解析 → HIDE" % sub_uuid)
			continue
		
		var sub_name := tr(sub_action.name) if not sub_action.name.is_empty() else sub_uuid
		var sub_reasons: Array[String] = []
		var is_hidden := false
		
		# ── Phase 0: prerequisite ──
		if sub_action.prerequisite:
			if not sub_action.prerequisite.compare(PlayerState):
				is_hidden = true
				Logging.info("[ActionManager] check_parent_action_children_availability: '%s' HIDE — prerequisite 不满足" % sub_uuid)
		
		# ── Phase 1: HIDE 检查 ──
		if not is_hidden and sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
			for req in sub_action.aciton_requirements:
				if req is _TraitRequirement or req is _FlagRequirement or req is _NarrativeLockRequirement:
					if not req.compare(PlayerState):
						is_hidden = true
						Logging.info("[ActionManager] check_parent_action_children_availability: '%s' HIDE — requirement type='%s' 不满足" % [sub_uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown"])
						break
		
		# Phase 1.5: ConsumeOldestImaginaryOperator viability
		if not is_hidden:
			var cost_arch_hide = Database.get_archetype_by_uuid(sub_action.uuid, "cost")
			if cost_arch_hide and not cost_arch_hide.operators.is_empty():
				for cop in cost_arch_hide.operators:
					if cop is _ConsumeOldestImaginaryOperator:
						if not _ConsumeOldestImaginaryOperator.is_viable():
							is_hidden = true
							Logging.info("[ActionManager] check_parent_action_children_availability: '%s' HIDE — ConsumeOldestImaginaryOperator.is_viable()=false" % sub_uuid)
							break
		
		if is_hidden:
			hidden_count += 1
			result.reasons.append(tr("CODE_ACTION_MANAGER_E29B9EECDB") % sub_name)
			Logging.info("[ActionManager] check_parent_action_children_availability: '%s' → HIDE, reason='%s'" % [sub_uuid, result.reasons.back()])
			continue
		
		# ── Phase 2: GRAY 检查 ──
		var is_gray := false
		
		if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
			for req in sub_action.aciton_requirements:
				if req is _PropertyRequirement or req is _PropRangeRequirement or req is _EmotionRequirement or req is _PoemRequirement:
					if not req.compare(PlayerState):
						is_gray = true
						var desc := ""
						if req.has_method("describe_requirement"):
							desc = req.describe_requirement()
						sub_reasons.append(desc if not desc.is_empty() else tr("CODE_ACTION_MANAGER_C3290E2AAD"))
						Logging.info("[ActionManager] check_parent_action_children_availability: '%s' GRAY — requirement type='%s' 不满足" % [sub_uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown"])
		
		# cost archetype 属性检查
		if not is_gray:
			var cost_arch_check = Database.get_archetype_by_uuid(sub_action.uuid, "cost")
			if cost_arch_check and not cost_arch_check.operators.is_empty():
				var arch_cost_reasons := check_archetype_property_costs(cost_arch_check.operators)
				if not arch_cost_reasons.is_empty():
					is_gray = true
					sub_reasons.append_array(arch_cost_reasons)
					Logging.info("[ActionManager] check_parent_action_children_availability: '%s' GRAY — cost archetype 属性不足: %s" % [sub_uuid, str(arch_cost_reasons)])
		
		# 时间检查（含异地惩罚）
		if not is_gray:
			var _is_remote := _RemoteActionFilterManager.is_action_remote(sub_action)
			var sub_cost := get_action_day_cost(sub_action, action.day_consumed, 1 if _is_remote else 0)
			if sub_cost > 0:
				var current_time := int(PlayerState.get_stat_val("time"))
				if current_time < sub_cost:
					is_gray = true
					var cost_detail := format_time_detail(action.day_consumed)
					sub_reasons.append(tr("CODE_ACTION_MANAGER_4267E5ADD3") % [current_time, cost_detail])
					Logging.info("[ActionManager] check_parent_action_children_availability: '%s' GRAY — 时间不足 (remote=%s)" % [sub_uuid, str(_is_remote)])
		
		if is_gray:
			gray_count += 1
			var reason_text := tr("CODE_ACTION_MANAGER_FEC6E6F4B1") % sub_name
			if not sub_reasons.is_empty():
				reason_text += "：" + "；".join(sub_reasons)
			result.reasons.append(reason_text)
			Logging.info("[ActionManager] check_parent_action_children_availability: '%s' → GRAY, reason='%s'" % [sub_uuid, reason_text])
		else:
			available_count += 1
			Logging.info("[ActionManager] check_parent_action_children_availability: '%s' → 可用" % sub_uuid)
	
	# ── 聚合判定 ──
	if hidden_count == total_subs:
		result.all_hidden = true
		result.all_unavailable = true
		Logging.info("[ActionManager] check_parent_action_children_availability: ═══ 全 HIDE: %d/%d ═══" % [hidden_count, total_subs])
	elif available_count == 0:
		# 不是全HIDE，但没有可用 → 全 GRAY（可能混合了 HIDE+GRAY）
		result.all_gray = true
		result.all_unavailable = true
		Logging.info("[ActionManager] check_parent_action_children_availability: ═══ 全 GRAY (或混合): hidden=%d gray=%d available=%d/%d ═══" % [hidden_count, gray_count, available_count, total_subs])
	else:
		Logging.info("[ActionManager] check_parent_action_children_availability: ═══ 正常: hidden=%d gray=%d available=%d/%d ═══" % [hidden_count, gray_count, available_count, total_subs])
	
	return result


func is_action_era_allowed(action: Action) -> bool:
	if GameState.current_era.is_empty():
		return true
	var era_res = Database.eras.get(GameState.current_era)
	if not era_res:
		return true
	
	var main_tag_val = action.get("_main_tag") if action is SceneAction else -1
	var action_type = ENUMS.action_tag_to_action_type(main_tag_val)
	
	# 黑名单优先（rejected_actions）
	var rejected = era_res.rejected_actions
	if rejected != null and not rejected.is_empty():
		if action_type >= 0 and rejected.has(action_type):
			return false
	
	# 白名单（accepted_actions）
	var accepted = era_res.accepted_actions
	if accepted != null and not accepted.is_empty():
		if action_type < 0 or not accepted.has(action_type):
			return false
	
	return true


## 🎯 纯函数：检查单个 action 在当前玩家状态下是否满足全部条件。
## 返回: { valid: bool, reasons: Array[String], prop_name: String, valid_hint: String }
## reasons 中每条是独立的失败原因文本（A类），最终会换行拼接到 dynamic_failed_hint。
## valid_hint 在 valid=true 时设置，包含精确数值的成功提示。
## 可复用于抽取阶段和属性变动后的重评估。
func check_action_validity(action: Action) -> Dictionary:
	var result := { "valid": true, "reasons": [], "prop_name": "", "valid_hint": "" }
	if not action:
		result.valid = false
		return result
	
	# 1. 从 archetype universal_result 解析属性消耗并检查
	# 🆕 委托给 static check_archetype_property_costs 统一处理
	var costs := _parse_archetype_costs(action)
	var cost_reasons := check_archetype_property_costs(costs)
	if not cost_reasons.is_empty():
		for reason in cost_reasons:
			result.reasons.append(reason)
		result.valid = false
		# 提取第一个 prop_name 用于提示
		for temp_op in costs:
			if temp_op is PropertyOperator and temp_op.value < 0:
				result.prop_name = temp_op.property
				break
		return result
	
	# 2. 检查时间消耗（使用 day_consumed + trait 惩罚）
	var cost := get_action_day_cost(action)
	if cost > 0:
		var current_time := int(PlayerState.get_stat_val("time"))
		var cost_detail := format_time_detail(action.day_consumed)
		if current_time < cost:
			result.valid = false
			var precise_line := tr("CODE_ACTION_MANAGER_4267E5ADD3") % [current_time, cost_detail]
			result.reasons.append(precise_line)
			result.prop_name = "time"
			return result
	
	# 3. 有效 action：构建成功提示（只展示消耗属性，不展示产出属性）
	var valid_parts: Array[String] = []
	if cost > 0:
		var current_time := int(PlayerState.get_stat_val("time"))
		var cost_detail := format_time_detail(action.day_consumed)
		valid_parts.append(tr("CODE_ACTION_MANAGER_1E3F359752") % [current_time, cost_detail])
	for temp_op in costs:
		if not temp_op is PropertyOperator:
			continue
		# 只展示 prop_sub（消耗为负），跳过 prop_add（产出为正）
		if temp_op.value >= 0:
			continue
		var prop_name = temp_op.property
		var current_val = int(PlayerState.get_stat_val(prop_name))
		var prop_data = Database.get_property(prop_name)
		var display_name = prop_data.get_display_name() if prop_data else prop_name
		valid_parts.append(tr("CODE_ACTION_MANAGER_D16BFC8474") % [display_name, current_val])
	if valid_parts.is_empty():
		result.valid_hint = tr("CODE_ACTION_MANAGER_F5B23A5C5F")
	else:
		valid_parts.append(tr("CODE_ACTION_MANAGER_F5B23A5C5F"))
		result.valid_hint = "\n".join(valid_parts)
	
	return result


## 连接 PlayerState.player_stat_changed 信号。
func connect_to_player_state() -> void:
	if _stat_signal_connected:
		return
	if PlayerState.has_signal("player_stat_changed"):
		if not PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
			PlayerState.player_stat_changed.connect(_on_player_stat_changed)
			_stat_signal_connected = true
			Logging.info("[ActionManager] 已连接 player_stat_changed 信号")


## 断开 PlayerState.player_stat_changed 信号。
func disconnect_from_player_state() -> void:
	if not _stat_signal_connected:
		return
	if PlayerState.has_signal("player_stat_changed"):
		if PlayerState.player_stat_changed.is_connected(_on_player_stat_changed):
			PlayerState.player_stat_changed.disconnect(_on_player_stat_changed)
	_stat_signal_connected = false


## 属性变动时重新评估已中签 action 的锁定状态。
## 原则：
## - 已中签的 action：条件满足→启用，条件不满足→A类灰化
## - 未中签的 action：跳过（B类叙事由 pick_top_actions() 统一管理）
## - 不重新随机抽取（保留 _selected_action_ids）
func reevaluate_all_locks() -> void:
	Logging.info("[ActionManager] ═══ 属性变动重评估启动 ═══")
	
	var all_actions := Database.get_actions_all()
	var changed := false
	
	for a_id in all_actions:
		var a = Database.get_action(a_id)
		if not a:
			continue
		
		# 跳过被 blocked 的 action
		if _blocked_actions.has(a_id):
			continue
		
		# 🆕 跳过 deferring 中的 action（其视觉状态由 defer 系统单独管理）
		if _deferring_actions.has(a.uuid):
			continue
		
		var validity := check_action_validity(a)
		
		if _selected_action_ids.has(a_id) and _selected_action_ids[a_id]:
			# 已中签：条件满足则启用（写入 success_hint），否则A类灰化
			a.clear_failed_hint()
			if validity.valid:
				if validity.get("valid_hint", ""):
					a.success_hint = validity.valid_hint
				changed = true
			else:
				for reason in validity.reasons:
					a.append_failed_hint(reason)
				changed = true
				Logging.info("[ActionManager] 🔄 reevaluate 已中签 A类: action=%s, hint='%s'" % [a_id, a.dynamic_failed_hint])
		# 🆕 未中签：跳过。B类叙事由 pick_top_actions() 统一设置，
		# reevaluate_all_locks 只负责已中签的 A类条件检查。
		# 不 touch dynamic_failed_hint，避免覆盖 pick_top_actions 的结果。
	
	if changed:
		EventBus.request_refresh_action_locks.emit()
		Logging.info("[ActionManager] ═══ 属性变动重评估完成，已发送刷新信号 ═══")
	else:
		Logging.info("[ActionManager] ═══ 属性变动重评估完成，无变化 ═══")


## 🆕 开始批量模式：行动执行期间抑制 reevaluate。
## 在 action_results.operate() 循环之前调用。
func begin_action_batch() -> void:
	_suppress_reevaluate = true

## 🆕 结束批量模式：解除抑制并统一执行一次 reevaluate。
## 在 action_results.operate() 循环之后调用。
func end_action_batch() -> void:
	_suppress_reevaluate = false
	reevaluate_all_locks()
	# 不再触发全量 refresh() — 全量刷新仅由 on_xun_tick 负责
	# 锁定态增量更新由 reevaluate_all_locks() → _refresh_locks_only() 处理


## player_stat_changed 信号回调。
## 🆕 使用 debounce 合并：100ms 内的多次 stat change 只触发一次 reevaluate_all_locks。
## 批量模式（_suppress_reevaluate）优先级高于 debounce — 批量期间直接跳过。
func _on_player_stat_changed(prop_name: String) -> void:
	# 🆕 批量模式下抑制重评估，由 end_action_batch 统一处理
	if _suppress_reevaluate:
		Logging.debug("[ActionManager] 批量模式，抑制 reevaluate: %s" % prop_name)
		return
	
	# 只对影响 action 可用性的属性变化做反应
	# 白名单: time / money / health / prestige / talent 都能影响 action 可用性
	if prop_name in ["time", "money", "health", "prestige", "talent", "astuteness", "composure", "inspiration", "momentum"]:
		Logging.info("[ActionManager] 关键属性 %s 变动，debounce 窗口启动 (%.0fms)" % [prop_name, STAT_DEBOUNCE_MS * 1000])
		_stat_debounce_pending = true
		_stat_debounce_timer.start(STAT_DEBOUNCE_MS)
	else:
		Logging.debug("[ActionManager] 属性 %s 变动，不在 action 重评估白名单中，跳过" % prop_name)


## 🆕 debounce 定时器回调：窗口期结束后统一执行一次 reevaluate
func _on_stat_debounce_timeout() -> void:
	if _stat_debounce_pending:
		_stat_debounce_pending = false
		Logging.info("[ActionManager] debounce 窗口结束，统一执行锁定重评估")
		reevaluate_all_locks()


# ════════════════════════════════════════════════════════════
# 持久化锁定/阻塞（多旬，跨回合）
# ════════════════════════════════════════════════════════════

## 将 ENUMS.ACTION_TYPE 枚举值转为 action ID 字符串（如 BAI_YE → "bai_ye"）
static func action_type_to_id(enum_val: int) -> String:
	if enum_val < 0 or enum_val >= ENUMS.ACTION_TYPE.size():
		return ""
	return ENUMS.ACTION_TYPE.keys()[enum_val].to_lower()


## 锁定一个 action（保证出现）。
## 如果该 action 已被 blocked，自动解除 blocked（冲突解决：后调用的赢）。
## xun_duration: -1 = 无限期，>0 = 持续 N 旬
## 返回 true 表示成功，false 表示无效 action_type
func lock_action(action_type: ENUMS.ACTION_TYPE, xun_duration: int = -1) -> bool:
	var action_id := action_type_to_id(action_type)
	if action_id.is_empty():
		Logging.err("[ActionManager] lock_action: 无效的 ACTION_TYPE 枚举值: %d" % action_type)
		return false
	
	# 1. 冲突解决：如果已被 blocked，移除 blocked
	if _blocked_actions.has(action_id):
		_blocked_actions.erase(action_id)
		Logging.info("[ActionManager] lock_action 冲突解除 blocked: %s" % action_id)
	
	# 2. 添加到锁列表
	_locked_in_actions[action_id] = xun_duration
	Logging.info("[ActionManager] 锁定 action: %s (持续 %d 旬)" % [action_id, xun_duration])
	
	# 3. 本回合立即生效
	reserve_action(action_id)
	return true


## 阻塞一个 action（阻止出现）。
## 如果该 action 已被 locked，自动解除 locked（冲突解决：后调用的赢）。
## xun_duration: -1 = 无限期，>0 = 持续 N 旬
## 返回 true 表示成功，false 表示无效 action_type
func block_action(action_type: ENUMS.ACTION_TYPE, xun_duration: int = -1) -> bool:
	var action_id := action_type_to_id(action_type)
	if action_id.is_empty():
		Logging.err("[ActionManager] block_action: 无效的 ACTION_TYPE 枚举值: %d" % action_type)
		return false
	
	# 1. 冲突解决：如果已被 locked，移除 locked
	if _locked_in_actions.has(action_id):
		_locked_in_actions.erase(action_id)
		Logging.info("[ActionManager] block_action 冲突解除 locked: %s" % action_id)
	
	# 2. 添加到阻塞列表
	_blocked_actions[action_id] = xun_duration
	Logging.info("[ActionManager] 阻塞 action: %s (持续 %d 旬)" % [action_id, xun_duration])
	
	# 3. 本回合立即生效：从预留中移除
	unreserve_action(action_id)
	return true


## 手动解锁一个 action
func unlock_action(action_type: ENUMS.ACTION_TYPE) -> void:
	var action_id := action_type_to_id(action_type)
	if action_id.is_empty():
		return
	_locked_in_actions.erase(action_id)
	Logging.info("[ActionManager] 解锁 action: %s" % action_id)


## 手动解阻塞一个 action
func unblock_action(action_type: ENUMS.ACTION_TYPE) -> void:
	var action_id := action_type_to_id(action_type)
	if action_id.is_empty():
		return
	_blocked_actions.erase(action_id)
	Logging.info("[ActionManager] 解阻塞 action: %s" % action_id)


## 按 action_id 字符串阻塞（用于不映射到 ENUMS.ACTION_TYPE 的 special action）。
## xun_duration: -1 = 无限期，>0 = 持续 N 旬
func block_action_by_id(action_id: String, xun_duration: int = -1) -> void:
	if action_id.is_empty():
		return
	# 冲突解决：如果已被 locked，移除 locked
	if _locked_in_actions.has(action_id):
		_locked_in_actions.erase(action_id)
		Logging.info("[ActionManager] block_action_by_id 冲突解除 locked: %s" % action_id)
	_blocked_actions[action_id] = xun_duration
	unreserve_action(action_id)
	Logging.info("[ActionManager] 阻塞 action (by id): %s (持续 %d 旬)" % [action_id, xun_duration])


## 按 action_id 字符串解阻塞。
func unblock_action_by_id(action_id: String) -> void:
	if action_id.is_empty():
		return
	_blocked_actions.erase(action_id)
	Logging.info("[ActionManager] 解阻塞 action (by id): %s" % action_id)


func is_action_locked(action_type: ENUMS.ACTION_TYPE) -> bool:
	var action_id := action_type_to_id(action_type)
	return _locked_in_actions.has(action_id)


func is_action_blocked(action_type: ENUMS.ACTION_TYPE) -> bool:
	var action_id := action_type_to_id(action_type)
	return _blocked_actions.has(action_id)


# ════════════════════════════════════════════════════════════
# 🆕 Tutorial 行动白名单（手动控制可见行动列表）
# ════════════════════════════════════════════════════════════

## 设置 tutorial 模式下可见的 action_id 白名单。
## 空数组 = 正常模式（不过滤），非空 = 只显示列表内的 action。
func set_tutorial_visible_actions(action_ids: Array[String]) -> void:
	_tutorial_whitelist = action_ids.duplicate()
	Logging.info("[ActionManager] set_tutorial_visible_actions: %s" % str(_tutorial_whitelist))

## 清空白名单，恢复所有 action 可见。
func clear_tutorial_whitelist() -> void:
	_tutorial_whitelist.clear()
	Logging.info("[ActionManager] clear_tutorial_whitelist: 白名单已清空，恢复所有行动可见")

## 获取当前白名单快照（供 ActionPanelManager 查询）。
func get_tutorial_whitelist() -> Array[String]:
	return _tutorial_whitelist.duplicate()

# ════════════════════════════════════════════════════════════
# 🆕 Tutorial 子行动白名单
# ════════════════════════════════════════════════════════════

var _tutorial_sub_whitelist: Array[String] = []

func set_tutorial_visible_sub_actions(action_ids: Array[String]) -> void:
	_tutorial_sub_whitelist = action_ids.duplicate()
	Logging.info("[ActionManager] set_tutorial_visible_sub_actions: %s" % str(_tutorial_sub_whitelist))

func clear_tutorial_sub_whitelist() -> void:
	_tutorial_sub_whitelist.clear()
	Logging.info("[ActionManager] clear_tutorial_sub_whitelist: 已清空")

func is_sub_action_tutorial_allowed(sub_action_id: String) -> bool:
	if _tutorial_sub_whitelist.is_empty():
		return true
	return _tutorial_sub_whitelist.has(sub_action_id)

## 检查指定 action_id 是否在白名单中。
## 白名单为空时：
##   - tutorial 未完成 → 全隐藏（Phase 7 写诗阶段不应展示任何行动）
##   - tutorial 已完成/未激活 → 全显示（正常模式）
func is_action_tutorial_allowed(action_id: String) -> bool:
	if _tutorial_whitelist.is_empty():
		if not PlayerState.has_flag("tutorial_completed"):
			Logging.info("[ActionManager] is_action_tutorial_allowed: tutorial 激活中且白名单为空，'%s' 被隐藏" % action_id)
			return false
		return true
	var allowed := _tutorial_whitelist.has(action_id)
	if not allowed:
		Logging.info("[ActionManager] is_action_tutorial_allowed: '%s' 不在 tutorial 白名单中，跳过" % action_id)
	return allowed


# ════════════════════════════════════════════════════════════
# 🆕 Defer 状态管理
# ════════════════════════════════════════════════════════════

## 查询一个 action 是否处于 deferring 状态。
func is_deferring(action_id: String) -> bool:
	return _deferring_actions.has(action_id)

## 查询一个 deferring action 是否即将资源不足（下一旬无法支付）。
## 实时调用 check_archetype_property_costs 做前瞻检查。
## @return true=下一旬付不起（按钮变红），false=没问题（按钮变蓝）。
func is_defer_failing(action_id: String) -> bool:
	if not _deferring_actions.has(action_id):
		return false
	var data: Dictionary = _deferring_actions[action_id]
	var arch_key: String = data.get("used_resource_archetype", "")
	if arch_key.is_empty():
		return false
	var archetype: ActionArchetype = Database.action_archetypes.get(arch_key)
	if not archetype or archetype.operators.is_empty():
		return false
	# 使用现有的 check_archetype_property_costs 做前瞻检查
	var reasons := check_archetype_property_costs(archetype.operators)
	return not reasons.is_empty()

## 获取 defer 剩余旬数（用于 hover 展示）。
## 不在 deferring 状态时返回 0。
func get_defer_remaining(action_id: String) -> int:
	if not _deferring_actions.has(action_id):
		return 0
	return _deferring_actions[action_id].get("remaining_xun", 0)

## 激活一个 action 的 defer 状态。
## 由 SceneActionPanel._on_button_pressed 在点击时调用。
func start_defer(action: Action, npc_target: String = "") -> void:
	if not action:
		Logging.err("[ActionManager] start_defer: action is null")
		return
	var config = action.defer_config
	if not config:
		Logging.err("[ActionManager] start_defer: action '%s' has no defer_config" % action.uuid)
		return
	if config.xun_defered.is_empty():
		Logging.err("[ActionManager] start_defer: action '%s' defer_config.xun_defered is empty" % action.uuid)
		return
	
	# 解析旬数
	var amounts = _NamedDSLParser._load_named_amounts()
	var total_xun: int = amounts.get(config.xun_defered, 0)
	if total_xun <= 0:
		Logging.err("[ActionManager] start_defer: xun_defered='%s' resolved to %d, invalid" % [config.xun_defered, total_xun])
		return
	
	# 解析 ap_cost
	var amounts_ap: int = amounts.get(config.ap_cost, 0)
	
	var action_id := action.uuid
	var main_tag: String = ""
	if action is _SceneAction:
		main_tag = (action as _SceneAction).main_tag
	
	_deferring_actions[action_id] = {
		"remaining_xun": total_xun,
		"used_resource_archetype": config.used_resource_archetype,
		"ap_cost": config.ap_cost,
		"failed_fallback": config.failed_fallback,
		"defer_success_event": config.defer_success_event,
		"main_tag": main_tag,
		"npc_target": npc_target,
		"event_picked_per_xun": config.event_picked_per_xun,
	}
	Logging.info("[ActionManager] ✅ 激活 defer: action=%s, xun=%d, ap_cost='%s'(%d), archetype='%s', fallback='%s', success_event='%s', per_xun_picker='%s'" % [
		action_id, total_xun, config.ap_cost, amounts_ap, config.used_resource_archetype, config.failed_fallback, config.defer_success_event,
		config.event_picked_per_xun if not config.event_picked_per_xun.is_empty() else "无"
	])
	
	# 通知 UI 刷新状态
	EventBus.request_refresh_action_locks.emit()

## 手动取消一个 defer（玩家点击淡蓝/红按钮时触发）。
## 清除 deferring 状态并刷新 UI。
func cancel_defer(action_id: String) -> void:
	if not _deferring_actions.has(action_id):
		Logging.warn("[ActionManager] cancel_defer: action '%s' 不在 deferring 状态" % action_id)
		return
	_deferring_actions.erase(action_id)
	Logging.info("[ActionManager] 🔵 手动取消 defer: action=%s" % action_id)
	EventBus.request_refresh_action_locks.emit()


## 每旬结算时调用（由 SurvivalManager.xun_tick 驱动）。
## 递减 locked/blocked 计数器，到期自动清除。
func process_xun_tick() -> void:
	Logging.info("[ActionManager] ═══ 旬结算开始 ═══")
	
	# ── 锁定到期清理 ──
	var expired_locks: Array[String] = []
	var decremented_locks: Array[String] = []
	for action_id in _locked_in_actions:
		var remaining: int = _locked_in_actions[action_id]
		if remaining == -1:
			continue  # 无限期
		remaining -= 1
		if remaining <= 0:
			expired_locks.append(action_id)
			Logging.info("[ActionManager] 🔓 锁定到期（完成解锁）: %s" % action_id)
		else:
			_locked_in_actions[action_id] = remaining
			decremented_locks.append(action_id)
	for action_id in expired_locks:
		_locked_in_actions.erase(action_id)
	
	# 🆕 锁定冷却递减通报
	if decremented_locks.size() > 0:
		var dec_lock_details: Array[String] = []
		for lid in decremented_locks:
			dec_lock_details.append(tr("CODE_ACTION_MANAGER_5576EB8849") % [lid, _locked_in_actions[lid]])
		Logging.info("[ActionManager] 🔒 锁定冷却递减 (%d): %s" % [decremented_locks.size(), ", ".join(dec_lock_details)])
	if expired_locks.size() > 0:
		Logging.info("[ActionManager] ✅ 锁定完全解锁 (%d): %s" % [expired_locks.size(), ", ".join(expired_locks)])
	
	# ── 阻塞到期清理 ──
	var expired_blocks: Array[String] = []
	var decremented_blocks: Array[String] = []
	for action_id in _blocked_actions:
		var remaining: int = _blocked_actions[action_id]
		if remaining == -1:
			continue
		remaining -= 1
		if remaining <= 0:
			expired_blocks.append(action_id)
			Logging.info("[ActionManager] 🟢 阻塞到期（完成解阻）: %s" % action_id)
		else:
			_blocked_actions[action_id] = remaining
			decremented_blocks.append(action_id)
	for action_id in expired_blocks:
		_blocked_actions.erase(action_id)
	
	# 🆕 阻塞冷却递减通报
	if decremented_blocks.size() > 0:
		var dec_block_details: Array[String] = []
		for bid in decremented_blocks:
			dec_block_details.append(tr("CODE_ACTION_MANAGER_5576EB8849") % [bid, _blocked_actions[bid]])
		Logging.info("[ActionManager] 🚫 阻塞冷却递减 (%d): %s" % [decremented_blocks.size(), ", ".join(dec_block_details)])
	if expired_blocks.size() > 0:
		Logging.info("[ActionManager] ✅ 阻塞完全解阻 (%d): %s" % [expired_blocks.size(), ", ".join(expired_blocks)])
	# 🆕 结算后状态汇总
	var active_locks: Array[String] = []
	for lid in _locked_in_actions:
		var rem = _locked_in_actions[lid]
		active_locks.append(tr("CODE_ACTION_MANAGER_54213AACF4") % [lid, "∞" if rem == -1 else str(rem)])
	var active_blocks: Array[String] = []
	for bid in _blocked_actions:
		var rem = _blocked_actions[bid]
		active_blocks.append(tr("CODE_ACTION_MANAGER_54213AACF4") % [bid, "∞" if rem == -1 else str(rem)])
	
	if active_locks.size() > 0 or active_blocks.size() > 0:
		Logging.info("[ActionManager] ═══ 旬结算后: 🔒锁定[%s] | 🚫阻塞[%s] ═══" % [", ".join(active_locks) if active_locks.size() > 0 else "无", ", ".join(active_blocks) if active_blocks.size() > 0 else "无"])
	else:
		Logging.info("[ActionManager] ═══ 旬结算后: 无任何锁定/阻塞 ═══")
	
	# ── 🆕 Defer 处理 ──
	Logging.info("[ActionManager] ═══ 旬结算: 处理 %d 个 deferring actions ═══" % _deferring_actions.size())
	var expired_defers: Array[String] = []
	var interrupted_defers: Array[String] = []
	var amounts := _NamedDSLParser._load_named_amounts()
	
	for action_id in _deferring_actions:
		var data: Dictionary = _deferring_actions[action_id]
		
		# ── 资源前瞻检查：不够就中断 ──
		var arch_key: String = data.get("used_resource_archetype", "")
		var arch: ActionArchetype = null
		if not arch_key.is_empty():
			arch = Database.action_archetypes.get(arch_key)
		
		if arch and not arch.operators.is_empty():
			var cost_reasons := check_archetype_property_costs(arch.operators)
			if not cost_reasons.is_empty():
				# 资源不足 → 强制中断 defer
				var failed_fb: String = data.get("failed_fallback", "")
				Logging.info("[ActionManager] ❌ 资源不足，强制中断 defer: action=%s, reasons=%s, fallback='%s'" % [
					action_id, ", ".join(cost_reasons), failed_fb
				])
				interrupted_defers.append(action_id)
				
				# 如果有兜底事件，push 它
				if not failed_fb.is_empty():
					var event_data = Database.resolve(failed_fb)
					Logging.info("[ActionManager] 🔍 defer中断诊断: failed_fb='%s', resolve result=%s" % [failed_fb, str(event_data)])
					if event_data:
						Logging.info("[ActionManager] 🔍 defer中断诊断: 即将 push_event, event_data type=%s, event_data.name=%s" % [typeof(event_data), event_data.name if event_data and event_data.has_method("get_name") else event_data.get("name", "?")])
						EventBus.push_event.emit(event_data)
						Logging.info("[ActionManager] 📖 中断 defer 后推送 fallback 事件: %s" % failed_fb)
					else:
						Logging.warn("[ActionManager] 中断 defer: fallback 事件 '%s' 未找到" % failed_fb)
				else:
					Logging.warn("[ActionManager] 🔍 defer中断诊断: failed_fallback 字段为空! action=%s, data keys=%s" % [action_id, str(data.keys())])
				continue  # 跳过本旬的资源消耗和递减
		else:
			# arch 为空或无 operators — 诊断日志：为什么资源检查被跳过？
			if arch_key.is_empty():
				Logging.info("[ActionManager] 🔍 defer中断诊断: used_resource_archetype 为空, action=%s → 跳过资源检查" % action_id)
			elif not arch:
				Logging.warn("[ActionManager] 🔍 defer中断诊断: archetype '%s' 未在 Database.action_archetypes 中找到, action=%s" % [arch_key, action_id])
			elif arch.operators.is_empty():
				Logging.info("[ActionManager] 🔍 defer中断诊断: archetype '%s' 的 operators 为空, action=%s" % [arch_key, action_id])
		
		# ── 🆕 per-xun 事件：消耗前触发，最后一旬跳过 ──
		var remaining_before: int = data.get("remaining_xun", 1)
		if remaining_before > 1:
			var picker_uuid: String = data.get("event_picked_per_xun", "")
			if not picker_uuid.is_empty():
				var picker: BaseEventPicker = Database.get_event_picker(picker_uuid)
				if picker != null:
					var npc_target: String = data.get("npc_target", "")
					var pick_ctx := {"action_id": action_id, "npc_target": npc_target}
					var picked_uuid: String = picker.pick(pick_ctx)
					if not picked_uuid.is_empty():
						var event_data = Database.resolve(picked_uuid)
						if event_data:
							Logging.info("[ActionManager] 📖 defer per-xun 事件推送: action=%s, remaining_before=%d, event=%s, picker='%s', npc_target='%s'" % [action_id, remaining_before, picked_uuid, picker_uuid, npc_target])
							EventBus.push_event.emit(event_data, pick_ctx)
						else:
							Logging.warn("[ActionManager] defer per-xun 事件 '%s' 未在 Database 中找到, action=%s" % [picked_uuid, action_id])
					else:
						Logging.info("[ActionManager] defer per-xun picker 返回空, action=%s, picker='%s'" % [action_id, picker_uuid])
				else:
					Logging.warn("[ActionManager] defer per-xun: picker UUID '%s' 在 Database.event_pickers 中未找到, action=%s" % [picker_uuid, action_id])
			else:
				Logging.info("[ActionManager] defer per-xun: action=%s 无 event_picked_per_xun 配置, remaining_before=%d" % [action_id, remaining_before])
		else:
			Logging.info("[ActionManager] defer 最后一旬跳过 per-xun 事件: action=%s, remaining=%d" % [action_id, remaining_before])
		
		# ── 资源充足：执行消耗 ──
		# 1. 执行 archetype.operators（扣资源）
		if arch and not arch.operators.is_empty():
			for op in arch.operators:
				if op is _PropertyOperator:
					var pop := op as _PropertyOperator
					Logging.info("[ActionManager] 📤 defer 每旬消耗: property=%s, value=%d" % [pop.property, pop.value])
					pop.operate()
		
		# 2. 扣除 ap_cost（时间）— ap_val 来自 named_amounts 是正数，用负值扣除
		var ap_key: String = data.get("ap_cost", "")
		if not ap_key.is_empty():
			var ap_val: int = amounts.get(ap_key, 0)
			if ap_val != 0:
				PlayerState.append_stat("_time", -ap_val)
				Logging.info("[ActionManager] ⏱ defer 每旬时间消耗: ap_cost='%s'(%d → _time %d)" % [ap_key, ap_val, -ap_val])
		
		# ── 递减 remaining_xun ──
		var remaining: int = data.get("remaining_xun", 1)
		remaining -= 1
		if remaining <= 0:
			expired_defers.append(action_id)
			Logging.info("[ActionManager] ✅ defer 到期完成: action=%s" % action_id)
		else:
			_deferring_actions[action_id]["remaining_xun"] = remaining
			Logging.info("[ActionManager] 🔄 defer 递减: action=%s, remaining=%d" % [action_id, remaining])
	
	# ── 清理已到期/已中断的 defer ──
	for action_id in expired_defers:
		# 到期 → 优先使用 defer_success_event，其次 main_tag scan_events，最后 fallback_event_uuid
		var data: Dictionary = _deferring_actions[action_id]
		var success_event: String = data.get("defer_success_event", "")
		var main_tag: String = data.get("main_tag", "")
		var npc_target: String = data.get("npc_target", "")
		_deferring_actions.erase(action_id)
		
		# ── 优先级 1: defer_success_event（精确指定）──
		if not success_event.is_empty():
			Logging.info("[ActionManager] 📖 defer 到期: 推 defer_success_event='%s' archetype_base='%s' outcome='success' npc_target='%s'" % [success_event, action_id, npc_target])
			EventBus.request_event_key.emit(success_event, {
				'archetype_base': action_id,
				'outcome': 'success',
				'npc_target': npc_target,
			})
		elif not main_tag.is_empty():
			Logging.info("[ActionManager] 📖 defer 到期触发器: scan_events with main_tag='%s' npc_target='%s'" % [main_tag, npc_target])
			var context := {
				'main_tag': main_tag,
				'fallback_event_uuid': "",
				'tag_match_mode': 'all',
				'archetype_base': action_id,
				'outcome': 'success',
				'npc_target': npc_target,
				'npc_target_name': "",
			}
			EventManager.scan_events(0, context)
		else:
			# 无 main_tag 的普通 Action（如 baiye_normal）：直接推 fallback 事件 + archetype context
			# RandomEvent.init() 会从 context 注入 archetype_base.success 的 operators（含 person_state）
			var fallback_uuid: String = ""
			var act = Database.get_action(action_id) as Action
			if act:
				fallback_uuid = act.fallback_event_uuid
			if not fallback_uuid.is_empty():
				Logging.info("[ActionManager] 📖 defer 到期（无main_tag）: 推 fallback 事件 '%s' + archetype_base='%s' outcome='success' npc_target='%s'" % [fallback_uuid, action_id, npc_target])
				EventBus.request_event_key.emit(fallback_uuid, {
					'archetype_base': action_id,
					'outcome': 'success',
					'npc_target': npc_target,
				})
			else:
				Logging.warn("[ActionManager] defer 到期但 main_tag 为空且无 fallback_event_uuid: action=%s" % action_id)
	
	for action_id in interrupted_defers:
		_deferring_actions.erase(action_id)
	
	# 🆕 defer 状态通报
	if expired_defers.size() > 0 or interrupted_defers.size() > 0 or _deferring_actions.size() > 0:
		var remaining_strs: Array[String] = []
		for aid in _deferring_actions:
			remaining_strs.append(tr("CODE_ACTION_MANAGER_302B5DE297") % [aid, _deferring_actions[aid].get("remaining_xun", 0)])
		Logging.info("[ActionManager] ═══ 旬结算 defer: ✅到期=%d | ❌中断=%d | 🔵剩余=[%s] ═══" % [
			expired_defers.size(), interrupted_defers.size(), ", ".join(remaining_strs)
		])
	
	# 发出刷新信号以便 UI 更新状态
	EventBus.request_refresh_action_locks.emit()


# ════════════════════════════════════════════════════════════
# 可用行动获取与抽取
# ════════════════════════════════════════════════════════════

func get_available_scene_actions() -> Dictionary:
	#breakpoint
	_collect_sub_action_ids()
	
	# 移除预留中的子 actions
	var to_remove := []
	for rid in _reserved_action_ids:
		if _all_sub_action_ids.has(rid):
			to_remove.append(rid)
	for rid in to_remove:
		_reserved_action_ids.erase(rid)
		Logging.info("[ActionManager] 预留 action 是子 action，已移除: %s" % rid)
	
	Logging.info("[ActionManager] ═══ 开始获取候选池 ═══")
	
	# 自动预留
	for action_id in _locked_in_actions:
		var ok := reserve_action(action_id)
		if ok:
			Logging.info("[ActionManager] _locked_in 触发自动预留: %s" % action_id)
	if _focus_controller.is_active():
		for fid in _focus_controller.get_focus_ids():
			if not fid in _reserved_action_ids:
				_reserved_action_ids.append(fid)
				Logging.info("[ActionManager] focus 触发自动预留: %s" % fid)
	if _reserved_action_ids.size() > 0:
		Logging.info("[ActionManager] 📌 本回合预留席位 (%d/%d): %s" % [_reserved_action_ids.size(), MAX_PICK_COUNT, ", ".join(_reserved_action_ids)])
	
	# 构建有效阻塞集（持久阻塞 + focus override）
	var all_actions := Database.get_actions_all()
	var _effective_blocked: Dictionary = _blocked_actions.duplicate()
	if _focus_controller.is_active():
		for bid in _focus_controller.get_block_override_ids(all_actions.keys()):
			_effective_blocked[bid] = -1
	for action_id in _effective_blocked:
		if action_id in _reserved_action_ids:
			_reserved_action_ids.erase(action_id)
	
	# 候选池 = 所有未阻塞 action（权重统一 1）
	var actions := {}
	for a_id in all_actions:
		if _effective_blocked.has(a_id):
			continue
		if _all_sub_action_ids.has(a_id):
			continue
		actions[a_id] = 1
	
	Logging.info("[ActionManager] 候选池: 总计=%d | 🚫阻塞=%d ═══" % [actions.size(), _effective_blocked.size()])
	return actions


## 🎲 从候选池中抽取 pick_count 个 action。
## 只做抽取 + 记录 selected_ids，不管理 hint/hidden 标志位。
## 由 SceneActionScroll 在 refresh() 后统一调用 apply_visibility_flags()。
func pick_top_actions(action_pool: Dictionary, pick_count: int = MAX_PICK_COUNT) -> Array[SceneAction]:
	Logging.info("[ActionManager] 🎲 开始抽取 (目标%d个, 池中%d, 预留%d)" % [pick_count, action_pool.size(), _reserved_action_ids.size()])
	
	if _reserved_action_ids.size() > action_pool.size():
		Logging.err("[ActionManager] 预留数量 (%d) 超过候选池 (%d)" % [_reserved_action_ids.size(), action_pool.size()])
		push_error(tr("CODE_ACTION_MANAGER_0E03C08950"))
		clear_reservations()
		return []
	
	var result := _ActionSelector.select(action_pool, _reserved_action_ids, pick_count)
	_selected_action_ids = result.selected_ids.duplicate()
	
	var names: Array[String] = []
	for sa in result.selected_actions:
		names.append(sa.uuid)
	Logging.info("[ActionManager] ═══ 本轮抽取: 共%d个 | 🔒预留%d | 🎲随机%d → %s ═══" % [result.selected_actions.size(), result.reserved_count, result.random_count, ", ".join(names)])
	
	clear_reservations()
	return result.selected_actions


## 集中设置所有 action 的 _is_hidden 和 dynamic_failed_hint 标志位。
## 由 SceneActionScroll 在 refresh() 中 pick 完成后调用。
## 三阶段：
## Phase 1: 清空标志位 (已在 pick_top_actions 中通过 clear_failed_hint 完成)
## Phase 2: HIDE — _is_hidden (era 不匹配 / blocked)
## Phase 3: LOCK — dynamic_failed_hint (属性不满足 / 未中签)
func apply_visibility_flags() -> void:
	_collect_sub_action_ids()
	Logging.info("[ActionManager] ═══ 开始设置可见性标志 ═══")
	
	# Phase 2: HIDE — 硬性拦截
	for a_id in Database.get_actions_all():
		var a := Database.get_action(a_id) as Action
		if not a:
			continue
		a.clear_failed_hint()  # 重置 _is_hidden + dynamic_failed_hint
		
		if _blocked_actions.has(a_id):
			a._is_hidden = true
			Logging.info("[ActionManager] 🔇 隐藏 %s — 原因: 被阻塞" % a_id)
		elif _all_sub_action_ids.has(a_id):
			a._is_hidden = true
			Logging.info("[ActionManager] 🔇 隐藏 %s — 原因: 是子 action" % a_id)
		elif not is_action_era_allowed(a):
			a._is_hidden = true
			Logging.info("[ActionManager] 🔇 隐藏 %s — 原因: Era不允许" % a_id)
		elif _focus_controller.is_active() and a_id not in _focus_controller.get_focus_ids():
			a._is_hidden = true
			Logging.info("[ActionManager] 🔇 隐藏 %s — 原因: Focus session 外" % a_id)
	
	# Phase 3: LOCK — 软性灰化（仅对 visible 的 action）
	for a_id in Database.get_actions_all():
		var a := Database.get_action(a_id) as Action
		if not a or a._is_hidden:
			continue
		
		if a_id in _selected_action_ids:
			# 已中签 → 检查属性需求
			var v := check_action_validity(a)
			if not v.valid and v.reasons.size() > 0:
				for reason in v.reasons:
					a.append_failed_hint(reason)
				Logging.info("[ActionManager] 🔒 中签但锁定 %s — %s" % [a_id, ", ".join(v.reasons)])
			elif v.get("valid_hint", ""):
				a.success_hint = v.valid_hint
		else:
			# 未中签 → B类 + A类
			if not a.lock_narrative.is_empty():
				a.append_failed_hint(a.lock_narrative)
			a.append_failed_hint(tr("CODE_ACTION_MANAGER_E29F84E3C5"))
			var v := check_action_validity(a)
			if not v.valid and v.reasons.size() > 0:
				for reason in v.reasons:
					a.append_failed_hint(reason)
			Logging.info("[ActionManager] 🔒 未中签锁定 %s" % a_id)
	
	# ── Phase 2.5: 子行动可用性聚合 — 父行动的子行动全灭时灰化父按钮 ──
	for a_id in Database.get_actions_all():
		var a := Database.get_action(a_id) as Action
		if not a or a._is_hidden:
			continue
		# 跳过子 action 本身（它们在 _all_sub_action_ids 中已被 _is_hidden）
		if a.sub_actions.is_empty():
			continue
		
		var children := check_parent_action_children_availability(a)
		if children.all_unavailable:
			var status_str := "HARD" if children.all_hidden else "SOFT"
			a._children_status = 2 if children.all_hidden else 1
			# 将子行动汇总原因注入 dynamic_failed_hint（hover 展示）
			var prefix := tr("CODE_ACTION_MANAGER_3E4B2F1A9C")  # "子行动均不可用: "
			if a.dynamic_failed_hint.is_empty():
				a.dynamic_failed_hint = prefix
			else:
				a.dynamic_failed_hint = prefix + a.dynamic_failed_hint
			for reason in children.reasons:
				a.dynamic_failed_hint += "\n  • " + reason
			Logging.info("[ActionManager] 🔒 父行动子行动全灭 %s — status=%s (%s)" % [a_id, status_str, a.dynamic_failed_hint])
		else:
			a._children_status = 0
			Logging.info("[ActionManager] ✅ 父行动子行动正常 %s" % a_id)


# ════════════════════════════════════════════════════════════
# 时间成本查询
# ════════════════════════════════════════════════════════════

## 计算子行动的有效天数：若子行动声明了 day_consumed（>0）则用它，否则继承父行动。
## @param action: 子行动
## @param parent_day: 父行动的 day_consumed
static func effective_day_consumed(action: Action, parent_day: float) -> float:
	if not action:
		Logging.warn("[ActionManager] effective_day_consumed: action is null, returning parent_day=%f" % parent_day)
		return parent_day
	if action.day_consumed > 0:
		Logging.info("[ActionManager] effective_day_consumed: sub '%s' override day_consumed=%f" % [action.uuid, action.day_consumed])
		return action.day_consumed
	Logging.info("[ActionManager] effective_day_consumed: sub '%s' inherits parent_day=%f" % [action.uuid, parent_day])
	return parent_day


## 获取行动的最终时间消耗（基础天数 + 所有活跃 trait 的时间惩罚 + 异地旅行惩罚）。
## 返回 int。无消耗时返回 0。
## @param parent_day: 若 >= 0 则为子行动模式，使用 effective_day_consumed 计算基础天数
## @param remote_penalty_days: 异地行动的额外旅行天数（默认 0，异地时传 1）
static func get_action_day_cost(action: Action, parent_day: float = -1.0, remote_penalty_days: int = 0) -> int:
	if not action:
		return 0
	
	var base := 0.0
	if parent_day >= 0.0:
		base = effective_day_consumed(action, parent_day)
	else:
		base = action.day_consumed
	
	if base <= 0 and remote_penalty_days <= 0:
		return 0
	
	var total := int(base) + remote_penalty_days
	var penalties := PlayerState.get_active_time_penalties()
	for penalty_days in penalties.values():
		total += penalty_days
	
	# 🆕 conditional_time_penalties 数据驱动：遍历所有 trait 的条件惩罚
	for t_name in PlayerState.traits:
		var t_data = Database.get_trait(t_name)
		if not t_data or t_data.conditional_time_penalties.is_empty():
			continue
		for ctp in t_data.conditional_time_penalties:
			var matched := false
			if ctp.add_to_all:
				matched = true
			elif not ctp.action_tag_match.is_empty():
				# 检查 main_tag（SceneAction）
				if action is SceneAction:
					if ctp.action_tag_match in (action as SceneAction).main_tag.to_lower():
						matched = true
				# 检查 action_tags
				if not matched:
					for tag in action.action_tags:
						if ctp.action_tag_match in tag.to_lower():
							matched = true
							break
			if matched:
				total += ctp.penalty_days
				Logging.info("[ActionManager] conditional_time_penalty: trait=%s tag=%s days=+%d desc=%s total=%d" % [t_name, ctp.action_tag_match, ctp.penalty_days, ctp.description, total])
	
	Logging.info("[ActionManager] get_action_day_cost: base=%d, remote_penalty=%d, penalties=%s → total=%d" % [int(base), remote_penalty_days, str(penalties), total])
	return total


## 格式化时间消耗的详细文本，包含各 trait 惩罚的标注。
## 例如：base=4, 崴脚+1 → "5天（+1, 由于 崴脚）"
## 无惩罚时 → "5天"
func format_time_detail(base_days: float) -> String:
	var total := int(base_days)
	var penalties := PlayerState.get_active_time_penalties()
	var extra := 0
	var penalty_names: Array[String] = []
	for name in penalties:
		var d := penalties[name] as int
		extra += d
		penalty_names.append(name)
	total += extra
	if penalty_names.is_empty():
		return tr("CODE_ACTION_MANAGER_4A67FE38B4") % total
	return tr("CODE_ACTION_MANAGER_27122C05D7") % [total, extra, "，".join(penalty_names)]


# ════════════════════════════════════════════════════════════
# Generator 消费（统一入口）
# ════════════════════════════════════════════════════════════

## 消费 action 上挂载的 generator 的一个 operator。
## 如果 generator 已耗尽，自动锁定 action 1 旬并清空 generator 引用。
## 由 SceneActionPanel 和 ActionMap 统一调用，避免逻辑重复。
func consume_generator(action: Action) -> void:
	if not action.generator:
		return
	
	var has_more := action.generator.execute_next()
	if not has_more:
		var gen_name := action.generator.name
		var action_type: int = action.generator.action_type
		lock_action(action_type as int, 1)
		action.generator = null
		Logging.info("[ActionManager] generator '%s' 已耗尽，action 锁定 1 旬，generator 已清空" % gen_name)


# ════════════════════════════════════════════════════════════
# 🆕 行动黑名单（全局永久过滤，不随 Era/旬变化，持久化到存档）
# ════════════════════════════════════════════════════════════

## 将 action UUID 加入全局黑名单。立即生效。
## 父 Action UUID → 整个 action（含子 action）不显示
## 子 Action UUID → 仅该子 action 不显示在 Picker 中
static func add_hidden_action(uuid: String) -> void:
	if uuid.is_empty():
		Logging.err("[ActionManager] add_hidden_action: uuid 为空，跳过")
		return
	if GameSave.data.hidden_action_uuids.has(uuid):
		Logging.info("[ActionManager] add_hidden_action: '%s' 已在黑名单中，跳过" % uuid)
		return
	GameSave.data.hidden_action_uuids.append(uuid)
	Logging.info("[ActionManager] ✅ add_hidden_action: '%s' 已加入黑名单（当前 %d 项）" % [uuid, GameSave.data.hidden_action_uuids.size()])
	# 触发面板重建以立即反映过滤
	if EventBus.has_signal("request_refresh_action_panel"):
		EventBus.request_refresh_action_panel.emit()


## 从黑名单中移除 action UUID。立即生效。
static func remove_hidden_action(uuid: String) -> void:
	if uuid.is_empty():
		Logging.err("[ActionManager] remove_hidden_action: uuid 为空，跳过")
		return
	if not GameSave.data.hidden_action_uuids.has(uuid):
		Logging.info("[ActionManager] remove_hidden_action: '%s' 不在黑名单中，跳过" % uuid)
		return
	GameSave.data.hidden_action_uuids.erase(uuid)
	Logging.info("[ActionManager] 🔓 remove_hidden_action: '%s' 已从黑名单移除（剩余 %d 项）" % [uuid, GameSave.data.hidden_action_uuids.size()])
	if EventBus.has_signal("request_refresh_action_panel"):
		EventBus.request_refresh_action_panel.emit()


## 检查 action UUID 是否在黑名单中。
static func is_action_hidden(uuid: String) -> bool:
	if uuid.is_empty():
		return false
	return GameSave.data.hidden_action_uuids.has(uuid)


## 获取当前黑名单快照（调试用）。
static func get_hidden_actions() -> Array[String]:
	return GameSave.data.hidden_action_uuids.duplicate()
