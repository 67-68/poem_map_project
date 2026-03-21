class_name PropertyRequirement extends BaseRequirements
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
@export_enum(
    'literary_fame',
    'official_prestige',
    'talent',
    'money'
) var property := ''

@export var value: int
@export var operator: REQ_OPERATOR.COMPARE
@export var failed_hint: String

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat(property)
	if not (stat_front):
		Logging.err('do not found stat %s in player stat, check pronounciation' % property)
		return 
	if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
		return stat_front < value
	else:
		return stat_front > value