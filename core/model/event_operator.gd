@tool
class_name EventOperator extends BaseOperator

@export var event_key: String

func operate():
    Logging.info("EventOperator: Triggering event with key: %s" % event_key)
    EventBus.request_event_key.emit(event_key)