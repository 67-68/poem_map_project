class_name PropertyRequirement extends BasePropertyOperator
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
@export var key: String
@export var value: int
@export var operator: String
@export var failed_hint: String

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat(key)
	if not (stat_front):
		Logging.err('do not found stat %s in player stat, check pronounciation' % key)
		return 
	if operator == '<':
		return stat_front < value
	else:
		return stat_front > value