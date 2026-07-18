@tool
class_name ActionMatchRequirement extends BaseRequirements
## ActionMatchRequirement — 检查当前 action_id 是否匹配
##
## 用于 BuffOperator.condition 字段，判断当前执行的 action 是否匹配指定 ID。
## 运行时读取 GameSave.data.current_action_id 做比较。
##
## DSL 语法（future）：requirement=action_match(action_id=denggao_shaolingyuan)

@export var action_id: String = ""


func compare(_data = null) -> bool:
	if action_id.is_empty():
		Logging.warn("ActionMatchRequirement.compare: action_id 为空，返回 false")
		return false

	var current_id: String = GameSave.data.current_action_id
	var matched := current_id == action_id
	Logging.info("ActionMatchRequirement.compare: 期望 action='%s', 当前 action='%s' → %s" % [action_id, current_id, "✅ 匹配" if matched else "❌ 不匹配"])
	return matched


func describe_requirement() -> String:
	if action_id.is_empty():
		return ""
	return tr("CODE_ACTION_MATCH_REQUIREMENT_C6CF49304D") % action_id


func get_referenced_flags() -> Array:
	return []


func get_referenced_traits() -> Array:
	return []
