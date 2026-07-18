@tool
class_name NPCFactionRequirement extends BaseRequirements
## NPCFactionRequirement — 检查当前交互 NPC 的派系是否匹配
##
## 用于 BuffOperator.condition 字段，判断当前 NPC 是否属于指定派系。
## 运行时读取 ModifierConfig.get_faction_from_context() 做比较。
##
## 派系值： "qingliu" | "zhuoliu" | "neutral"

@export var faction: String = "qingliu"  # qingliu / zhuoliu / neutral


func compare(_data = null) -> bool:
	if faction.is_empty():
		Logging.warn("NPCFactionRequirement.compare: faction 为空，返回 false")
		return false

	var current_faction: int = ModifierConfig.get_faction_from_context()
	var current_str: String = ModifierConfig.faction_to_filter(current_faction)
	var matched := current_str == faction
	Logging.info("NPCFactionRequirement.compare: 期望 faction='%s', 当前 faction='%s' → %s" % [faction, current_str, "✅ 匹配" if matched else "❌ 不匹配"])
	return matched


func describe_requirement() -> String:
	var faction_cn := ""
	match faction:
		"qingliu":
			faction_cn = tr("CODE_RIGHT_INFO_PANEL_92C54C878B")
		"zhuoliu":
			faction_cn = tr("CODE_NPC_FACTION_REQUIREMENT_02BAE0D4E1")
		_:
			faction_cn = faction
	return tr("CODE_NPC_FACTION_REQUIREMENT_C528572287") % faction_cn


func get_referenced_flags() -> Array:
	return []


func get_referenced_traits() -> Array:
	return []
