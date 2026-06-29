extends Node
const _Action = preload("res://core/model/action.gd")
const _ActionArchetype = preload("res://core/model/action_archetype.gd")
const _CooldownFilter = preload("res://core/model/cooldown_filter.gd")
const _Era = preload("res://core/model/era.gd")
const _FocusActionOperator = preload("res://core/operators/focus_action_operator.gd")
const _Generator = preload("res://core/model/generator.gd")
const _MicroDSLParser = preload("res://parser/micro_dsl_parser.gd")
const _SceneAction = preload("res://core/model/scene_action.gd")
const _SceneActionPanel = preload("res://ui/action_button.gd")
const _NamedDSLParser = preload("res://parser/named_dsl_parser.gd")
const _SurvivalManager = preload("res://core/survival_manager.gd")
const _TimeOperator = preload("res://core/model/time_operator.gd")
const _PropertyOperator = preload("res://core/model/property_operator.gd")

const MAX_PICK_COUNT: int = 6

## 每回合即时预留（抽取后清空）
var _reserved_action_ids: Array[String] = []

## 持久化锁定（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _locked_in_actions: Dictionary = {}

## 持久化阻塞（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _blocked_actions: Dictionary = {}

## Focus session 状态（点击计数制，非旬制）
var _focus_action_ids: Array[String] = []
var _focus_click_remaining: int = 0

## 🆕 本轮已抽中的 action ID 集合（key=action_id, val=true）。
## 属性变动重评估时，已中签的 action 保留此标记，未中签的永远灰化。
var _selected_action_ids: Dictionary = {}

## 🆕 缓存 event_archetypes.json 中的 failed_hints 字段
## 结构: { archetype_key: { prop_name: narrative_text } }

## 🆕 是否已连接 player_stat_changed 信号（防重连）
var _stat_signal_connected: bool = false

## 🆕 批量模式守卫：行动执行期间抑制 reevaluate，全部 results 执行完后统一评估。
var _suppress_reevaluate: bool = false


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
## 返回: { valid: bool, reasons: Array[String], prop_name: String }
## reasons 中每条是独立的失败原因文本（A类），最终会换行拼接到 dynamic_failed_hint。
## 可复用于抽取阶段和属性变动后的重评估。
func check_action_validity(action: Action) -> Dictionary:
	var result := { "valid": true, "reasons": [], "prop_name": "" }
	if not action:
		result.valid = false
		return result
	
	# 1. 从 archetype universal_result 解析属性消耗并检查
	var costs := _parse_archetype_costs(action)
	for temp_op in costs:
		if not temp_op is PropertyOperator:
			continue
		var req: PropertyRequirement = temp_op.convert_prop_limit_requirement()
		if req != null and not req.compare(PlayerState):
			result.valid = false
			var hint: String = req.get_failed_hint()
			if hint.is_empty():
				hint = req.describe_requirement()
			if hint.is_empty():
				hint = "条件未满足"
			result.reasons.append(hint)
			
			var prop_name: String = temp_op.property
			if not prop_name.is_empty():
				result.prop_name = prop_name
				var archetype_hint := _get_archetype_failed_hint(action, prop_name)
				if not archetype_hint.is_empty():
					Logging.info("[ActionManager] ✅ archetype hint 命中: action=%s, prop=%s, hint='%s'" % [action.uuid, prop_name, archetype_hint])
					result.reasons[-1] = archetype_hint
			# 只报告第一个失败的限制
			return result
	
	# 2. 检查时间消耗（集成时间锁定）
	var cost := get_action_day_cost(action)
	if cost > 0:
		var current_time := int(PlayerState.get_stat_val("time"))
		if current_time < cost:
			result.valid = false
			var time_hint := _get_archetype_failed_hint(action, "time")
			if time_hint.is_empty():
				time_hint = "这个行动需要 " + str(cost) + " 天，时间不足"
			result.reasons.append(time_hint)
			result.prop_name = "time"
			return result
	
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
			# 已中签：条件满足则启用，否则A类灰化
			if validity.valid:
				if not a.dynamic_failed_hint.is_empty():
					a.clear_failed_hint()
					changed = true
			else:
				a.clear_failed_hint()
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
	# 🆕 强制刷新 action 面板（兜底 on_xun_tick → refresh() 信号可能失效的情况）
	EventBus.request_refresh_action_panel.emit()


## player_stat_changed 信号回调。
func _on_player_stat_changed(prop_name: String) -> void:
	# 🆕 批量模式下抑制重评估，由 end_action_batch 统一处理
	if _suppress_reevaluate:
		Logging.debug("[ActionManager] 批量模式，抑制 reevaluate: %s" % prop_name)
		return
	
	# 只对影响 action 可用性的属性变化做反应
	# 白名单: time / money / health / literary_fame / talent 都能影响 action 可用性
	if prop_name in ["time", "money", "health", "literary_fame", "talent"]:
		Logging.info("[ActionManager] 关键属性 %s 变动，触发锁定重评估" % prop_name)
		reevaluate_all_locks()
	else:
		Logging.debug("[ActionManager] 属性 %s 变动，不在 action 重评估白名单中，跳过" % prop_name)


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
	Logging.info("[ActionManager] ═══ 开始获取可用场景动作 ═══")
	
	# ── 确保 archetype 缓存已加载 ──
	if Database.action_archetypes.is_empty():
		_init_archetype_cache()
	
	# ── Phase 0 前置通报：当前锁定/阻塞状态 ──
	if _locked_in_actions.size() > 0:
		var locked_list: Array[String] = []
		for lid in _locked_in_actions:
			var rem = _locked_in_actions[lid]
			locked_list.append("%s(%s旬)" % [lid, "∞" if rem == -1 else str(rem)])
		Logging.info("[ActionManager] 🔒 当前持久锁定 (%d): %s" % [_locked_in_actions.size(), ", ".join(locked_list)])
	if _blocked_actions.size() > 0:
		var blocked_list: Array[String] = []
		for bid in _blocked_actions:
			var rem = _blocked_actions[bid]
			blocked_list.append("%s(%s旬)" % [bid, "∞" if rem == -1 else str(rem)])
		Logging.info("[ActionManager] 🚫 当前持久阻塞 (%d): %s" % [_blocked_actions.size(), ", ".join(blocked_list)])
	
	# ── Phase 0.5: 清空上轮 selected_ids ──
	_selected_action_ids.clear()
	
	# ── Phase 0: _locked_in 驱动自动预留 ──
	for action_id in _locked_in_actions:
		var ok := reserve_action(action_id)
		if ok:
			Logging.info("[ActionManager] _locked_in 触发自动预留: %s" % action_id)
	
	# ── Phase 0.5: _blocked 过滤 ──
	# 如果被 blocked 的 action 被误预留了，清掉
	for action_id in _blocked_actions:
		if action_id in _reserved_action_ids:
			_reserved_action_ids.erase(action_id)
			Logging.info("[ActionManager] _blocked 过滤，移除预留: %s" % action_id)
	
	if _reserved_action_ids.size() > 0:
		Logging.info("[ActionManager] 📌 本回合预留席位 (%d/%d): %s" % [_reserved_action_ids.size(), MAX_PICK_COUNT, ", ".join(_reserved_action_ids)])
	
	var actions := {}
	var num_with_npc := 0   # 「有人」计数器
	var num_solo := 0       # 「无人」计数器
	var num_intercepted := 0 # 被拦截计数器
	
	var all_actions := Database.get_actions_all()
	Logging.info("[ActionManager] 总动作池大小: %d，blocked: %d，locked: %d" % [all_actions.size(), _blocked_actions.size(), _locked_in_actions.size()])
	
	# 统一去 base_prov 里拿位置数据
	var loc = Database.get_province(PlayerState.current_location)
	if not loc:
		Logging.err("当前位置幽灵化: %s" % PlayerState.current_location)
		return actions
	Logging.info("[ActionManager] 当前位置: %s, area_tags: %s" % [PlayerState.current_location, str(loc.area_tags)])
	
	# 连接 player_stat_changed 信号（仅连接一次）
	connect_to_player_state()
	
	for a_id in all_actions:
		var a = Database.get_action(a_id)
		var is_valid = true # 🤓☝️ 设立拦截签证！
		
		# 🆕 判定「有人」/「无人」（基于 CD 目标推导）
		var action_npc_label := "无人"
		if a is SceneAction:
			var main_tag_str: String = a.main_tag if a.main_tag else ""
			if not main_tag_str.is_empty():
				var cd_target := CooldownFilter._derive_cooldown_target(main_tag_str)
				if not cd_target.is_empty():
					action_npc_label = "有人→%s" % cd_target
				else:
					action_npc_label = "无人"
		
		# 0. 检查是否被 blocked
		if _blocked_actions.has(a_id):
			Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 被阻塞" % [action_npc_label, a_id])
			num_intercepted += 1
			continue
		
		# 1. 检查硬性需求 (Requirements) — 使用 check_action_validity 复用
		var validity := check_action_validity(a)
		if not validity.valid:
			is_valid = false
			Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: %s" % [action_npc_label, a_id, ", ".join(validity.reasons)])
		
		if not is_valid:
			Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 不满足需求条件" % [action_npc_label, a_id])
			num_intercepted += 1
			continue # 这个 continue 才会跳过外层的 a_id！
			
		# 2. 检查标签匹配 (Tags)
		if a.area_tags and not a.area_tags.is_empty():
			var tag_matched = false
			if loc.area_tags:
				for tag in loc.area_tags:
					if tag in a.area_tags:
						tag_matched = true
						break
						
			if not tag_matched:
				Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 标签不匹配 (loc=%s, action=%s)" % [action_npc_label, a_id, str(loc.area_tags), str(a.area_tags)])
				num_intercepted += 1
				continue # 没有交集，直接滚蛋
				
		# 4. Era 合法性检查（复用 is_action_era_allowed）
		if not is_action_era_allowed(a):
			Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: Era不允许 (era=%s)" % [action_npc_label, a_id, GameState.current_era])
			num_intercepted += 1
			continue
	
		# 3. 活到最后的才是合法动作
		var locked_mark := " 🔒" if _locked_in_actions.has(a_id) else ""
		Logging.info("[ActionManager] ✅ 装载 [%s] %s%s" % [action_npc_label, a_id, locked_mark])
		append_counter(actions, a_id, a)
		if action_npc_label.begins_with("有人"):
			num_with_npc += 1
		else:
			num_solo += 1
	
	# 🆕 最终汇总
	var unlocked_count := actions.size() - _locked_in_actions.size()
	Logging.info("[ActionManager] ═══ 可用池汇总: 总合法=%d | 👤有人=%d | 🚶无人=%d | 🔒已锁定=%d | 🔓未锁定=%d | 🚫拦截=%d ═══" % [actions.size(), num_with_npc, num_solo, _locked_in_actions.size(), max(0, unlocked_count), num_intercepted])
	return actions


func append_counter(counter: Dictionary, item_name: String, _item) -> Dictionary:
	if counter.has(item_name):
		counter[item_name] += 1
	else:
		counter[item_name] = 1
	return counter

func get_total_weight_power2(actions: Dictionary) -> float:
	var total_weight = 0.0
	for action_id in actions:
		total_weight += pow(actions[action_id], 2)
	return total_weight

## 🎲 抽取行动并标记中签/未中签状态。
## 改造后：除了返回选中的 actions，还会：
## 1. 记录中签的 action_id 到 _selected_action_ids
## 2. 为未中签的合法 action 设置 B类锁定叙事文本
## 3. 为所有 action 清空 dynamic_failed_hint 后重建
func pick_top_actions(action_pool: Dictionary, pick_count: int = MAX_PICK_COUNT) -> Array[SceneAction]:
	var selected_actions: Array[SceneAction] = []
	var available_pool = action_pool.duplicate() # 复制一份，避免污染原池
	
	Logging.info("[ActionManager] 🎲 开始抽取行动 (目标%d个, 池中%d, 预留%d)" % [pick_count, action_pool.size(), _reserved_action_ids.size()])
	
	# --- Phase 0: 清空所有 action 的 dynamic_failed_hint ---
	for a_id in Database.get_actions_all():
		var a = Database.get_action(a_id)
		if a:
			a.clear_failed_hint()
	
	# --- Phase 1: 处理预留席位 ---
	if _reserved_action_ids.size() > 0:
		# 校验：预留数量不能超过可用池大小
		if _reserved_action_ids.size() > available_pool.size():
			Logging.err("[ActionManager] 预留数量 (%d) 超过当前可用行动数量 (%d)，无法抽取" % [_reserved_action_ids.size(), available_pool.size()])
			Logging.err("ActionManager: 预留数量超过当前可用行动数量")
			push_error("超过当前可用行动数量")
			clear_reservations()
			return selected_actions
		
		for reserved_id in _reserved_action_ids:
			if selected_actions.size() >= pick_count:
				break
			if available_pool.has(reserved_id):
				selected_actions.append(Database.get_action(reserved_id) as SceneAction)
				available_pool.erase(reserved_id)
				Logging.info("[ActionManager] 🎯 预留抽取: %s" % reserved_id)
			else:
				Logging.err("[ActionManager] 预留 action %s 不在当前可用池中！" % reserved_id)
				Logging.err("ActionManager: 预留 action 不在当前可用池: %s" % reserved_id)
				push_error("不在当前可用池")
				# 继续处理其他预留，但这个跳过
	
	# --- Phase 2: 随机填充剩余席位 ---
	var remaining_slots = pick_count - selected_actions.size()
	while selected_actions.size() < pick_count and available_pool.size() > 0:
		var total_weight = get_total_weight_power2(available_pool)
		
		# 2. 转动命运的轮盘
		var roll = randf_range(0.0, total_weight)
		var cursor = 0.0
		
		# 3. 寻找中奖者
		for action_id in available_pool:
			cursor += pow(available_pool[action_id], 2)
			if roll <= cursor:
				selected_actions.append(Database.get_action(action_id) as SceneAction)
				available_pool.erase(action_id) # 拿走，不放回！
				Logging.info("[ActionManager] 🎲 随机抽取: %s" % action_id)
				break # 必须 break，进入下一轮抽取
	
	# --- Phase 3: 标记中签/未中签 ---
	# 已中签的记录到 _selected_action_ids
	_selected_action_ids.clear()
	for sa in selected_actions:
		_selected_action_ids[sa.uuid] = true
	
	# 未中签的合法 action → B类锁定
	for a_id in action_pool:
		if a_id in _selected_action_ids:
			continue
		if _blocked_actions.has(a_id):
			continue
		var a = Database.get_action(a_id)
		if a:
			if not a.lock_narrative.is_empty():
				a.append_failed_hint(a.lock_narrative)
			# 同时追加 B类通用文本
			a.append_failed_hint("此路不通，换个主意吧")
	
	# ── 🆕 Phase 3.5: 非池 action 恢复 A 类 hint ──
	# 被 get_available_scene_actions 排除的 action 在 Phase 0 中被清空 hint，
	# 需要重新检查 validity 并补回 A 类叙事文本。
	for a_id in Database.get_actions_all():
		if a_id in action_pool:
			continue
		if _blocked_actions.has(a_id):
			continue
		var a = Database.get_action(a_id)
		if not a:
			continue
		var validity := check_action_validity(a)
		if not validity.valid and validity.reasons.size() > 0:
			a.clear_failed_hint()
			for reason in validity.reasons:
				a.append_failed_hint(reason)
			Logging.info("[ActionManager] 🏷️ 非池 action hint 恢复: id=%s, reasons='%s'" % [a_id, ", ".join(validity.reasons)])
	
	# 🆕 抽取结果汇总
	var reserved_count := 0
	var random_count := 0
	if _reserved_action_ids.size() > 0:
		reserved_count = min(_reserved_action_ids.size(), selected_actions.size())
	random_count = selected_actions.size() - reserved_count
	
	var npc_count := 0
	var solo_count := 0
	var names: Array[String] = []
	for sa in selected_actions:
		names.append(sa.uuid)
		if sa is SceneAction:
			var main_tag_str: String = sa.main_tag if sa.main_tag else ""
			if not main_tag_str.is_empty():
				var cd_target := CooldownFilter._derive_cooldown_target(main_tag_str)
				if cd_target.is_empty():
					solo_count += 1
				else:
					npc_count += 1
	
	Logging.info("[ActionManager] ═══ 本轮抽取结果: 共%d个 | 🔒预留%d | 🎲随机%d | 👤有人%d | 🚶无人%d → %s ═══" % [selected_actions.size(), reserved_count, random_count, npc_count, solo_count, ", ".join(names)])
	
	# 抽取完成后自动清除预留，避免跨回合污染
	clear_reservations()
	return selected_actions


# ════════════════════════════════════════════════════════════
# 时间成本查询
# ════════════════════════════════════════════════════════════

## 从 action.action_results 中提取 TimeOperator 的 day 消耗。
## 返回 int，无 TimeOperator 时返回 0。
static func get_action_day_cost(action: Action) -> int:
	if not action or not action.action_results:
		return 0
	for op in action.action_results:
		if op is TimeOperator:
			return max(0, int(op.day))
	return 0


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
# Focus Session（点击计数制 — 针对 FocusActionOperator）
# ════════════════════════════════════════════════════════════

## 启动 focus session：block 非 focus + lock focus，持续 click_count 次点击。
## 由 FocusActionOperator.operate() 调用。
## 返回 true 表示成功。
func start_focus_session(focus_types: Array, click_count: int) -> bool:
	if focus_types.is_empty() or click_count <= 0:
		Logging.err("[ActionManager] start_focus_session: 参数无效 (focus=%d, click=%d)" % [focus_types.size(), click_count])
		return false

	# ── 1. 计算聚焦 action_id 集合 ──
	var focus_ids: Array[String] = []
	for at in focus_types:
		var id := action_type_to_id(at)
		if not id.is_empty() and id not in focus_ids:
			focus_ids.append(id)

	# ── 2. 计算非聚焦集合（遍历 Database 实际 action 池，而不是仅 ENUMS.ACTION_TYPE）──
	# 这样 special action（如 DeepSeek）也能被 block。
	var all_action_ids := Database.get_actions_all().keys()
	var other_ids: Array[String] = []
	for a_id in all_action_ids:
		if a_id not in focus_ids and a_id not in other_ids:
			# 跳过已被 block 的 action（避免重复操作）
			if not _blocked_actions.has(a_id):
				other_ids.append(a_id)

	# ── 3. Block 所有非聚焦（先 block，用 by_id 方法覆盖 special actions）──
	for oid in other_ids:
		block_action_by_id(oid, -1)

	# ── 4. Lock 所有聚焦（后 lock，冲突解除 step 3 的 block）──
	for fid in focus_ids:
		var at: ENUMS.ACTION_TYPE = ENUMS.ACTION_TYPE[fid.to_upper()] as ENUMS.ACTION_TYPE
		lock_action(at, -1)

	# ── 5. 记录 session 状态（用 all_action_ids 快照，结束时可准确恢复）──
	_focus_action_ids = focus_ids.duplicate()
	_focus_click_remaining = click_count

	# ── 6. 发射 UI 信号 ──
	var selected_actions: Array[SceneAction] = []
	for action_id in focus_ids:
		var action := Database.get_action(action_id) as SceneAction
		if action:
			selected_actions.append(action)
	if selected_actions.size() > 0:
		EventBus.selected_actions_change.emit(selected_actions)
	EventBus.locked_actions_selected.emit(selected_actions)

	# ── 7. 通知 UI 进入 focus 模式（隐藏写诗按钮等）──
	EventBus.focus_session_changed.emit(true)

	Logging.info("[ActionManager] 🔦 Focus session 启动: focus=%s, others blocked(from pool)=%d, click_remaining=%d" % [", ".join(focus_ids), other_ids.size(), click_count])
	return true


## 每次行动点击后调用（由 action_button.gd 触发）。
## 递减计数器，归零时自动释放 focus session。
func on_focus_action_clicked() -> void:
	if _focus_click_remaining <= 0:
		return

	_focus_click_remaining -= 1
	Logging.info("[ActionManager] 🔦 Focus session click: remaining=%d" % _focus_click_remaining)

	if _focus_click_remaining <= 0:
		_end_focus_session()


## 强制结束 focus session（也可被新 session 覆盖调用）。
func _end_focus_session() -> void:
	if _focus_action_ids.is_empty():
		return

	# ── 解锁所有 focus actions ──
	for fid in _focus_action_ids:
		var at: ENUMS.ACTION_TYPE = ENUMS.ACTION_TYPE[fid.to_upper()] as ENUMS.ACTION_TYPE
		unlock_action(at)

	# ── 解阻塞所有 action（包括 special actions，用 by_id 覆盖完整 action 池）──
	var all_action_ids := Database.get_actions_all().keys()
	for a_id in all_action_ids:
		if a_id not in _focus_action_ids and _blocked_actions.has(a_id):
			unblock_action_by_id(a_id)

	Logging.info("[ActionManager] 🔓 Focus session 结束，已释放 %d 个 focus + 恢复其余 action" % _focus_action_ids.size())

	_focus_action_ids.clear()
	_focus_click_remaining = 0

	# ── 通知 UI 退出 focus 模式（恢复写诗按钮等）──
	EventBus.focus_session_changed.emit(false)

	# ── 刷新 UI ──
	EventBus.request_refresh_action_panel.emit()


## 查询当前是否处于 focus session 中。
func is_in_focus_session() -> bool:
	return _focus_click_remaining > 0


## 获取当前 focus session 剩余点击次数（-1 表示不在 session 中）。
func get_focus_click_remaining() -> int:
	if _focus_click_remaining <= 0:
		return -1
	return _focus_click_remaining
