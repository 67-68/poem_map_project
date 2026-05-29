@tool
class_name PushEventOperator extends BaseOperator

## 要推送的事件 key（支持 BaseEvent 的 uuid 或 String key）
@export var event_key: String

## 当前事件的 context，在 init 时注入，emit 时一并传递
var _captured_context: Dictionary = {}

func operate():
	Logging.info("PushEventOperator: Pushing event with key: %s" % event_key)
	EventBus.push_event.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	return context
