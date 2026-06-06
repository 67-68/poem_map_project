@tool
class_name InfoDemoOperator extends BaseOperator

@export var info: String = ''

func operate():
    EventBus.request_toast.emit(info, 1)