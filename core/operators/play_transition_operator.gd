@tool
class_name PlayTransitionOperator extends BaseOperator

## 过场文字序列，每段依次显示（淡入淡出切换）
@export var texts: Array[String] = []

var _captured_context: Dictionary = {}

func operate():
	Logging.info("PlayTransitionOperator: 播放过场文字，%d 段" % texts.size())
	EventBus.push_cinematic.emit(texts)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	return context
