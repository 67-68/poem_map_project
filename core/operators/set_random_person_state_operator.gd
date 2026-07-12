@tool
class_name SetRandomPersonStateOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# SetRandomPersonStateOperator — 坊间买醉：随机 T1 uncharted → not_meet（听人提起）
#
# DSL 语法:
#   set_random_person_state(tier=1; state=not_meet)
#
# 参数:
#   tier:  目标社会层级（1=T1市井, 0=全层级）
#   state: 目标 person_state 值（如 not_meet）
#
# 行为:
#   1. 从 RELATION_TARGET_TIER 筛选匹配 tier 的目标
#   2. 过滤 person_state == uncharted 的目标（尚未被发现的陌生人）
#   3. 随机选一个，设置其 person_state 为 not_meet（听人提起此人）
#   4. 若无符合条件的目标，打 err 并静默返回
# ═══════════════════════════════════════════════════════════

@export var tier: int = 1
@export var state: String = ""

func operate():
	Logging.info("[SetRandomPersonStateOperator] operate: tier=%d, state=%s" % [tier, state])
	
	if state.is_empty():
		Logging.err("[SetRandomPersonStateOperator] state 为空，操作中止")
		return
	
	# 1. 收集符合 tier 且 person_state == uncharted 的目标（尚未被发现的陌生人）
	var candidates: Array[String] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		
		# tier 过滤（0 表示不限层级）
		if tier > 0:
			var target_tier = RelationFlagManager.RELATION_TARGET_TIER.get(target_tag, 0)
			if target_tier != tier:
				continue
		
		# person_state 过滤：只选 uncharted（从未被发现的陌生人）
		var current_state = RelationFlagManager.get_person_state(target_tag)
		if current_state != RelationFlagManager.PERSON_STATE.UNCHARTED:
			Logging.info("[SetRandomPersonStateOperator] 跳过 %s（当前状态=%s，非 uncharted）" % [target_tag, current_state])
			continue
		
		candidates.append(target_tag)
	
	if candidates.is_empty():
		Logging.info("[SetRandomPersonStateOperator] tier=%d 层级无 uncharted 目标可用" % tier)
		show_hint("酒酣耳热之际环顾四周，却无值得结交之人")
		return
	
	# 2. 随机选一个
	var chosen: String = candidates[randi() % candidates.size()]
	Logging.info("[SetRandomPersonStateOperator] 随机选中 target=%s（candidates=%s）" % [chosen, str(candidates)])
	
	# 3. 设置 person_state
	RelationFlagManager.set_person_state(chosen, state)
	Logging.info("[SetRandomPersonStateOperator] %s person_state → %s" % [chosen, state])
	
	show_hint("酒酣耳热之际，听人提起了%s" % chosen)


func describe_preview() -> String:
	return "在酒馆中听人提起新面孔"
