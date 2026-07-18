@tool
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

## 操作模式
## - append: 累加（默认行为）
## - set: 直接设值
## - reduce_to_lowest_zero: 如果当前值 > value 则减去 value，否则归零
@export_enum('append', 'set', 'reduce_to_lowest_zero') var mode: String = 'append'

## 情绪英文键 → 中文名映射（与 ui/emotion_radar.gd 保持一致）
var _EMOTION_CN_NAMES: Dictionary = {
	"sorrow": tr("CODE_EMOTION_REQUIREMENT_192BC492B2"),
	"arrogance": tr("CODE_EMOTION_REQUIREMENT_9A85FF3DCC"),
	"anger": tr("CODE_EMOTION_REQUIREMENT_DC917B1566"),
	"tranquility": tr("CODE_EMOTION_REQUIREMENT_A62908DEDA"),
	"ambition": tr("CODE_EMOTION_REQUIREMENT_0AB342DF06"),
}

func _get_emotion_cn_name() -> String:
	return _EMOTION_CN_NAMES.get(emotion, emotion)

func describe_preview() -> String:
	if value == 0:
		return ""
	var cn_name = _get_emotion_cn_name()
	var arrow = "↑" if value > 0 else "↓"
	match mode:
		'reduce_to_lowest_zero':
			return "%s↓(%d)" % [cn_name, value]
		'set':
			return "%s → %d" % [cn_name, value]
		_:
			return "%s%s(%+d)" % [cn_name, arrow, value]

func operate():
	# 先处理 archetype 效果
	if archetype != -1:
		Archetypes.translate_archetype(archetype, PlayerState)
	
	# 再根据 mode 处理 emotion 效果
	match mode:
		'append':
			PlayerState.append_emotion(emotion, value)
		'set':
			PlayerState.set_emotion(emotion, value)
		'reduce_to_lowest_zero':
			var current = PlayerState.get_emotion(emotion)
			if current > value:
				PlayerState.set_emotion(emotion, current - value)
				Logging.info('EmotionOperator.reduce_to_lowest_zero: %s reduced from %d to %d (value=%d)' % [emotion, current, current - value, value])
			else:
				PlayerState.set_emotion(emotion, 0)
				Logging.info('EmotionOperator.reduce_to_lowest_zero: %s reset from %d to 0 (value=%d, current <= value)' % [emotion, current, value])
