extends Node

const MAX_PICK_COUNT: int = 6

## 每回合即时预留（抽取后清空）
var _reserved_action_ids: Array[String] = []

## 持久化锁定（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _locked_in_actions: Dictionary = {}

## 持久化阻塞（多旬生效），key=action_id, val=剩余旬数（-1=无限）
var _blocked_actions: Dictionary = {}


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
		
		# 1. 检查硬性需求 (Requirements)
		if a.aciton_requirements:
			for req in a.aciton_requirements:
				if not req.compare(PlayerState):
					is_valid = false # 签证拒签！
					Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 需求未满足 → %s" % [action_npc_label, a_id, req.describe_requirement()])
					break # 💀 打断内层循环，直接判死刑
					
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
				
		# 4. Era 合法性检查（三层语义）
		if not GameState.current_era.is_empty():
			var era_res = Database.eras.get(GameState.current_era)
			if era_res:
				var main_tag_val = a.get("_main_tag") if a is SceneAction else -1
				var action_type = ENUMS.action_tag_to_action_type(main_tag_val)
				
				# 4a. 黑名单优先（rejected_actions）
				# null / [] → 不拦截
				# [...] → 拦截列表中指定的所有 action_type
				var rejected = era_res.rejected_actions
				if rejected != null and not rejected.is_empty():
					if action_type >= 0 and rejected.has(action_type):
						Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 时代黑名单 (era=%s)" % [action_npc_label, a_id, GameState.current_era])
						num_intercepted += 1
						continue
				
				# 4b. 白名单（accepted_actions）
				# null → 全部允许（不拦截）
				# []   → 全部禁止（拦截一切）
				# [...] → 白名单（仅列表中的放行）
				var accepted = era_res.accepted_actions
				if accepted != null:
					if action_type < 0 or not accepted.has(action_type):
						Logging.info("[ActionManager] 🚫 拦截 [%s] %s — 原因: 不在时代白名单 (era=%s)" % [action_npc_label, a_id, GameState.current_era])
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

func pick_top_actions(action_pool: Dictionary, pick_count: int = MAX_PICK_COUNT) -> Array[SceneAction]:
	var selected_actions: Array[SceneAction] = []
	var available_pool = action_pool.duplicate() # 复制一份，避免污染原池
	
	Logging.info("[ActionManager] 🎲 开始抽取行动 (目标%d个, 池中%d, 预留%d)" % [pick_count, action_pool.size(), _reserved_action_ids.size()])
	
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
