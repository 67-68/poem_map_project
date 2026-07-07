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

const MAX_PICK_COUNT: int = 6

## 每回合即时预留（抽取后清空）
var _reserved_action_ids: Array[String] = []

## 持久化锁定（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _locked_in_actions: Dictionary = {}

## 持久化阻塞（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _blocked_actions: Dictionary = {}

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
		push_error("预留席位已满")
		return false
	
	# 2. 检查是否重复预定
	if action_id in _reserved_action_ids:
		Logging.err("[ActionManager] action 已被重复预定: %s" % action_id)
		push_error("重复预定")
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

## 将 event_archetypes.json 加载到 Database.action_archetypes 中。
## 每项转为 ActionArchetype Resource，以 archetype key 索引。
func _init_archetype_cache() -> void:
	if not Database.action_archetypes.is_empty():
		return
	var file := FileAccess.open("res://tools/data/event_archetypes.json", FileAccess.READ)
	if not file:
		Logging.warn("[ActionManager] 无法读取 event_archetypes.json")
		return
	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		Logging.err("[ActionManager] event_archetypes.json 解析失败: " + json.get_error_message())
		return
	var data: Dictionary = json.data
	for archetype_key in data:
		if data[archetype_key] is Dictionary:
			var entry: Dictionary = data[archetype_key]
			Database.action_archetypes[archetype_key] = ActionArchetype.from_json(entry)
	Logging.info("[ActionManager] 已加载 %d 个 action archetype" % Database.action_archetypes.size())


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


## 🆕 解析 archetype 的 universal_result DSL，提取属性消耗并创建临时 PropertyOperator。
## universal_result 格式: "prop_sub(name=money; val=m_money_cost)|prop_add(name=health; val=m_health_loss)"
## 返回 Array[PropertyOperator]，每个代表一个属性消耗。
func _parse_archetype_costs(action: Action) -> Array:
	var costs: Array = []
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
static func check_archetype_property_costs(operators: Array) -> Array[String]:
	var reasons: Array[String] = []
	if operators.is_empty():
		return reasons
	
	for op in operators:
		if not op is _PropertyOperator:
			continue
		var pop := op as _PropertyOperator
		if pop.value >= 0:
			continue  # 只检查消耗（负值），收益不拦截
		var req: PropertyRequirement = pop.convert_prop_limit_requirement()
		if req != null and not req.compare(PlayerState):
			var prop_name: String = pop.property
			var current_val = PlayerState.get_stat_val(prop_name)
			var prop_data = Database.get_property(prop_name)
			var prop_display_name = prop_data.get_display_name() if prop_data else prop_name
			var needed := req.value
			var precise_line := "「%s」不足，当前%d，需要%d" % [prop_display_name, current_val, needed]
			reasons.append(precise_line)
			Logging.info("[ActionManager] check_archetype_property_costs: prop=%s current=%d needed=%d → GRAY" % [prop_name, current_val, needed])
	
	Logging.info("[ActionManager] check_archetype_property_costs: %d operators → %d reasons" % [operators.size(), reasons.size()])
	return reasons



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
			var precise_line := "时间剩余%d天，但这项行动需要%s" % [current_time, cost_detail]
			result.reasons.append(precise_line)
			result.prop_name = "time"
			return result
	
	# 3. 有效 action：构建成功提示（只展示消耗属性，不展示产出属性）
	var valid_parts: Array[String] = []
	if cost > 0:
		var current_time := int(PlayerState.get_stat_val("time"))
		var cost_detail := format_time_detail(action.day_consumed)
		valid_parts.append("时间充足（剩余%d天，需要%s）" % [current_time, cost_detail])
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
		valid_parts.append("「%s」充足（当前%d）" % [display_name, current_val])
	if valid_parts.is_empty():
		result.valid_hint = "条件满足"
	else:
		valid_parts.append("条件满足")
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
	# 白名单: time / money / health / literary_fame / talent 都能影响 action 可用性
	if prop_name in ["time", "money", "health", "literary_fame", "talent"]:
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
			dec_lock_details.append("%s→%d旬" % [lid, _locked_in_actions[lid]])
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
			dec_block_details.append("%s→%d旬" % [bid, _blocked_actions[bid]])
		Logging.info("[ActionManager] 🚫 阻塞冷却递减 (%d): %s" % [decremented_blocks.size(), ", ".join(dec_block_details)])
	if expired_blocks.size() > 0:
		Logging.info("[ActionManager] ✅ 阻塞完全解阻 (%d): %s" % [expired_blocks.size(), ", ".join(expired_blocks)])
	
	# 🆕 结算后状态汇总
	var active_locks: Array[String] = []
	for lid in _locked_in_actions:
		var rem = _locked_in_actions[lid]
		active_locks.append("%s(%s旬)" % [lid, "∞" if rem == -1 else str(rem)])
	var active_blocks: Array[String] = []
	for bid in _blocked_actions:
		var rem = _blocked_actions[bid]
		active_blocks.append("%s(%s旬)" % [bid, "∞" if rem == -1 else str(rem)])
	
	if active_locks.size() > 0 or active_blocks.size() > 0:
		Logging.info("[ActionManager] ═══ 旬结算后: 🔒锁定[%s] | 🚫阻塞[%s] ═══" % [", ".join(active_locks) if active_locks.size() > 0 else "无", ", ".join(active_blocks) if active_blocks.size() > 0 else "无"])
	else:
		Logging.info("[ActionManager] ═══ 旬结算后: 无任何锁定/阻塞 ═══")


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
		push_error("超过当前可用行动数量")
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
			a.append_failed_hint("此路不通，换个主意吧")
			var v := check_action_validity(a)
			if not v.valid and v.reasons.size() > 0:
				for reason in v.reasons:
					a.append_failed_hint(reason)
			Logging.info("[ActionManager] 🔒 未中签锁定 %s" % a_id)


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


## 获取行动的最终时间消耗（基础天数 + 所有活跃 trait 的时间惩罚）。
## 返回 int。无消耗时返回 0。
## @param parent_day: 若 >= 0 则为子行动模式，使用 effective_day_consumed 计算基础天数
static func get_action_day_cost(action: Action, parent_day: float = -1.0) -> int:
	if not action:
		return 0
	
	var base := 0.0
	if parent_day >= 0.0:
		base = effective_day_consumed(action, parent_day)
	else:
		base = action.day_consumed
	
	if base <= 0:
		return 0
	
	var total := int(base)
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
	
	Logging.info("[ActionManager] get_action_day_cost: base=%d, penalties=%s → total=%d" % [int(base), str(penalties), total])
	return total


## 格式化时间消耗的详细文本，包含各 trait 惩罚的标注。
## 例如：base=4, 崴脚+1 → "5天（+1, 由于 崴脚）"
## 无惩罚时 → "5天"
static func format_time_detail(base_days: float) -> String:
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
		return "%d天" % total
	return "%d天（+%d, 由于 %s）" % [total, extra, "，".join(penalty_names)]


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
