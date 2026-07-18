@tool
class_name PropertyRequirement extends BaseRequirements
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
@export var property := ''
@export var value: int
@export var operator: REQ_OPERATOR.COMPARE

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat_val(property)
	# get_stat_val 对缺失 key 会 Logging.err + return 0，此处不再重复报 0 值
	if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
		return stat_front < value
	else:
		return stat_front > value

func describe_requirement() -> String:
	if property.is_empty():
		return ""
	var prop = Database.get_property(property)
	if not prop:
		return ""
	var perception = prop.get_staged_perception_at_threshold(value)
	if perception.is_empty() or perception == tr("CODE_RANGE_REQUIREMENT_EC0D9BDB00"):
		return ""
	return tr("CODE_RANGE_REQUIREMENT_B0E2EB548E") % [value, perception]

func get_referenced_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []
