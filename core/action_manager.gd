extends Node

const MAX_PICK_COUNT: int = 6
var _reserved_action_ids: Array[String] = []

## 持有这些 trait 时，自动预定对应的行动
const TRAIT_AUTO_RESERVE_MAP: Dictionary = {
	"reserve_baiye": "bai_ye",
}

## 预定一个 action，确保本回合必定被选中。
## 返回 true 表示预定成功，false 表示失败（见 push_error）。
func reserve_action(action_id: String) -> bool:
	# 1. 检查席位是否已满
	if _reserved_action_ids.size() >= MAX_PICK_COUNT:
		Logging.err("[ActionManager] 预留席位已满 (%d/%d)，预定失败: %s" % [MAX_PICK_COUNT, MAX_PICK_COUNT, action_id])
		push_error("ActionManager: 预留席位已满，预定失败")
		return false
	
	# 2. 检查是否重复预定
	if action_id in _reserved_action_ids:
		Logging.err("[ActionManager] action 已被重复预定: %s" % action_id)
		push_error("ActionManager: 重复预定 action: %s" % action_id)
		return false
	
	_reserved_action_ids.append(action_id)
	Logging.info("[ActionManager] 预定成功: %s (当前 %d/%d)" % [action_id, _reserved_action_ids.size(), MAX_PICK_COUNT])
	return true


## 清除所有预定（每次抽取后自动调用）
func clear_reservations() -> void:
	_reserved_action_ids.clear()


func get_available_scene_actions() -> Dictionary:
	#breakpoint
	print("[ActionManager] 开始获取可用场景动作")

	# ── Phase 0: Trait 驱动自动预定 ──
	for trait_id in TRAIT_AUTO_RESERVE_MAP:
		if PlayerState.has_trait(trait_id):
			var action_id := TRAIT_AUTO_RESERVE_MAP[trait_id] as String
			var ok := reserve_action(action_id)
			if ok:
				Logging.info("[ActionManager] trait %s 触发自动预定: %s" % [trait_id, action_id])

	var actions := {}
	
	# 统一去 base_prov 里拿位置数据
	var loc = Database.base_province.get(PlayerState.current_location)
	if not loc:
		Logging.err("当前位置幽灵化: %s" % PlayerState.current_location)
		return actions

	for a_id in Database.actions:
		var a = Database.actions[a_id]
		var is_valid = true # 🤓☝️ 设立拦截签证！
		
		# 1. 检查硬性需求 (Requirements)
		if a.aciton_requirements:
			for req in a.aciton_requirements:
				if not req.compare(PlayerState):
					is_valid = false # 签证拒签！
					break # 💀 打断内层循环，直接判死刑
					
		if not is_valid:
			print("[ActionManager] 动作 %s 不满足需求条件，被拦截" % a_id)
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
				print("[ActionManager] 动作 %s 标签不匹配当前位置" % a_id)
				continue # 没有交集，直接滚蛋
				
		# 3. 活到最后的才是合法动作
		print("[ActionManager] 动作 %s 完全合法，允许装载" % a_id)
		append_counter(actions, a_id, a)
		
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
	
	# --- Phase 1: 处理预留席位 ---
	if _reserved_action_ids.size() > 0:
		# 校验：预留数量不能超过可用池大小
		if _reserved_action_ids.size() > available_pool.size():
			Logging.err("[ActionManager] 预留数量 (%d) 超过当前可用行动数量 (%d)，无法抽取" % [_reserved_action_ids.size(), available_pool.size()])
			push_error("ActionManager: 预留数量超过当前可用行动数量")
			clear_reservations()
			return selected_actions
		
		for reserved_id in _reserved_action_ids:
			if selected_actions.size() >= pick_count:
				break
			if available_pool.has(reserved_id):
				selected_actions.append(Database.actions[reserved_id] as SceneAction)
				available_pool.erase(reserved_id)
			else:
				Logging.err("[ActionManager] 预留 action %s 不在当前可用池中！" % reserved_id)
				push_error("ActionManager: 预留 action 不在当前可用池: %s" % reserved_id)
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
				selected_actions.append(Database.actions[action_id] as SceneAction)
				available_pool.erase(action_id) # 拿走，不放回！
				break # 必须 break，进入下一轮抽取
				
	# 抽取完成后自动清除预留，避免跨回合污染
	clear_reservations()
	return selected_actions
