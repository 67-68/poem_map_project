@tool
class_name PlayTransitionOperator extends BaseOperator

## 过场文字序列，每段依次显示（淡入淡出切换）
@export var texts: Array[String] = []

## 遮罩层透明度（0 = 完全不透明黑遮罩，1 = 完全透明无遮罩）
@export var overlay_opacity: float = 0.0

var _captured_context: Dictionary = {}

func operate():
	Logging.info("PlayTransitionOperator: 播放过场文字，%d 段" % texts.size())
	var config := {"overlay_opacity": overlay_opacity}
	EventBus.push_cinematic.emit(texts, config)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	return context
