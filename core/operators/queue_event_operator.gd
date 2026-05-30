@tool
class_name QueueEventOperator extends BaseOperator

## 要排入队列的事件 key（通过 request_event_key 信号排入普通事件队列）
@export var event_key: String

## 当前事件的 context，在 init 时注入，operate 时一并传递
var _captured_context: Dictionary = {}

func operate():
	Logging.info("QueueEventOperator: Queueing event with key: %s, context keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	if _captured_context.has("guests"):
		Logging.info("QueueEventOperator: guests value = %s" % str(_captured_context.get("guests")))
	EventBus.request_event_key.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("QueueEventOperator.init: captured context for event %s, keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	return context
