class_name EmotionOperator extends BaseOperator

@export var _emotion: ENUMS.EMOTION = ENUMS.EMOTION.SORROW
var emotion := '':
	get:
		if str_emotion:
			return str_emotion
		Logging.warn("EmotionOperator: string emotion not set, use enum emotion")
		return ENUMS.to_emotion_str(_emotion)
	set(value):
		str_emotion = value

var str_emotion: String = ""
@export var value: int = 0

@export var archetype: Archetypes.ARCHETYPE = -1 # -1 表示未设置，对应 archetypes.gd 中的 ARCHETYPE 枚举

func operate():
	# 先处理 archetype 效果
	if archetype != -1:
		Archetypes.translate_archetype(archetype, PlayerState)
	
	# 再处理 emotion 效果
	PlayerState.change_emotion(emotion, value)
