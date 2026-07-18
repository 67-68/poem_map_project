@tool
class_name AllEmoSubOperator extends BaseOperator

## 对所有情绪执行 reduce_to_lowest_zero 操作
## 每个情绪减去 value（最低归零），不清零已为 0 的情绪

@export var value: int = 0

func operate():
	if value == 0:
		Logging.warn("AllEmoSubOperator: value=0，跳过")
		return

	Logging.info("AllEmoSubOperator: 对所有情绪执行 reduce_to_lowest_zero(value=%d)" % value)

	for i in ENUMS.EMOTION.size():
		var emo_name = ENUMS.to_emotion_str(i)
		var current = PlayerState.get_emotion(emo_name)
		if current > value:
			PlayerState.set_emotion(emo_name, current - value)
			Logging.debug("AllEmoSubOperator: %s reduced from %d to %d" % [emo_name, current, current - value])
		else:
			PlayerState.set_emotion(emo_name, 0)
			Logging.debug("AllEmoSubOperator: %s reset from %d to 0" % [emo_name, current])

func describe_preview() -> String:
	if value == 0:
		return ""
	return tr("CODE_ALL_EMO_SUB_OPERATOR_AD44EE7793") % value

func get_referenced_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []

func get_demanded_flags() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
