@tool
class_name EmotionRequirement extends BaseRequirements
# 在意象校验中使用，用来判断某个player state的情绪是否达标

# 单个情绪 requirement，使用 ENUMS.EMOTION 格式
@export_enum(
	'sorrow',
	'arrogance',
	'anger',
	'tranquility',
	'ambition',
) var volatile_stat := ''

@export var value: int
@export var operator: REQ_OPERATOR.COMPARE

## 情绪英文键 → 中文名映射
const _EMOTION_CN: Dictionary = {
	"sorrow": "愁苦",
	"arrogance": "狂傲",
	"anger": "愤懑",
	"tranquility": "旷达",
	"ambition": "野心",
}

func describe_requirement() -> String:
	if volatile_stat.is_empty():
		return ""
	var cn = _EMOTION_CN.get(volatile_stat, volatile_stat)
	# 简略显示，不暴露具体数值
	return "需要情绪: %s" % cn

func compare(player_state: PlayerState):
	var stat_front = player_state.get_emotion(volatile_stat)
	if not (stat_front):
		Logging.err('do not found emotion %s in player emotions, check pronounciation' % volatile_stat)
		return false
	if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
		return stat_front < value
	else:
		return stat_front > value
