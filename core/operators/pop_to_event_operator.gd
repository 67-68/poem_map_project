@tool
class_name PopToEventOperator extends BaseOperator

## 要弹出到的事件 key（在 _event_stack 中搜索该 uuid/name 并弹出到那一层）
@export var event_key: String

func operate():
	Logging.info("PopToEventOperator: Popping to event key: %s" % event_key)
	EventBus.pop_to_event.emit(event_key)

func init(context: Dictionary) -> Dictionary:
	Logging.info("PopToEventOperator.init: will pop to event %s" % event_key)
	return context
