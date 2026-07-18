@tool
class_name NPCTierRequirement extends BaseRequirements
## NPCTierRequirement — 检查当前交互 NPC 的社会阶层是否匹配
##
## 用于 BuffOperator.condition 字段，判断当前 NPC 是否属于指定社会阶层。
## 运行时读取 ModifierConfig.get_faction_from_context() 获取目标 tag，
## 然后查 RelationFlagManager.RELATION_TARGET_TIER 做比较。
##
## tier 值： 1=T1市井, 2=T2文人, 3=T3权贵

@export var tier: int = 1


func compare(_data = null) -> bool:
	if tier < 1 or tier > 3:
		Logging.warn("NPCTierRequirement.compare: tier=%d 非法，返回 false" % tier)
		return false

	# 从上下文获取当前 NPC tag
	var target_tag: String = PlayerState.last_event.get("target_tag", "")
	if target_tag.is_empty():
		# fallback: 从 current_action_tags 中提取
		for tag in PlayerState.current_action_tags:
			if tag.begins_with("actor:npc:"):
				target_tag = tag.replace("actor:npc:", "")
				break

	if target_tag.is_empty():
		Logging.debug("NPCTierRequirement.compare: 无当前 NPC 上下文，返回 false")
		return false

	# 获取 NPC 的 tier
	var npc_tier: int = RelationFlagManager.RELATION_TARGET_TIER.get(target_tag, 0)
	var matched := npc_tier == tier
	Logging.info("NPCTierRequirement.compare: target='%s', 期望 tier=%d, 实际 tier=%d → %s" % [target_tag, tier, npc_tier, "✅ 匹配" if matched else "❌ 不匹配"])
	return matched


func describe_requirement() -> String:
	var tier_cn := ""
	match tier:
		1:
			tier_cn = tr("CODE_NPC_TIER_REQUIREMENT_B5B9D84ABF")
		2:
			tier_cn = tr("CODE_NPC_TIER_REQUIREMENT_C74492EB54")
		3:
			tier_cn = tr("CODE_NPC_TIER_REQUIREMENT_E4CA3EA091")
	return tr("CODE_NPC_TIER_REQUIREMENT_83FDDD20EC") % tier_cn


func get_referenced_flags() -> Array:
	return []


func get_referenced_traits() -> Array:
	return []
