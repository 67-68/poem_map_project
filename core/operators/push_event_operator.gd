@tool
class_name PushEventOperator extends BaseOperator

## 要推送的事件 key（支持 BaseEvent 的 uuid 或 String key）
@export var event_key: String

## 当前事件的 context，在 init 时注入，emit 时一并传递
var _captured_context: Dictionary = {}

func operate():
	Logging.info("PushEventOperator: Pushing event with key: %s, context keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	if _captured_context.has("guests"):
		Logging.info("PushEventOperator: guests value = %s" % str(_captured_context.get("guests")))
	EventBus.push_event.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("PushEventOperator.init: captured context for event %s, keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	return context
