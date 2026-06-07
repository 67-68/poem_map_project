@tool
class_name PropertyRequirement extends BaseRequirements
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
@export var property := ''
@export var value: int
@export var operator: REQ_OPERATOR.COMPARE

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat_val(property)
	if not (stat_front):
		Logging.err('do not found stat %s in player stat, check pronounciation' % property)
		return
	if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
		return stat_front < value
	else:
		return stat_front > value

func get_referenced_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []
