class_name EmotionRequirement extends BaseRequirements
# 在选项中使用，用来判断某个player state的volatile stat是否达标

# 单个volatile stat requirement
@export_enum(
	'temp_health_sick',
	'temp_health_drunk',
	'temp_emotion_despair',
	'temp_emotion_ambition',
	'temp_fatigue',
	'temp_stress',
	'temp_inspiration',
) var volatile_stat := ''

@export var value: int
@export var operator: REQ_OPERATOR.COMPARE
@export var failed_hint: String

func compare(player_state: PlayerState):
	var stat_front = player_state.get_emotion(volatile_stat)
	if not (stat_front):
		Logging.err('do not found volatile stat %s in player volatile stats, check pronounciation' % volatile_stat)
		return 
	if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
		return stat_front < value
	else:
		return stat_front > value