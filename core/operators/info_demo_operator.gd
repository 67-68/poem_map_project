@tool
class_name InfoDemoOperator extends BaseOperator

@export var info: String = ''

func operate():
    EventBus.request_warning_toast.emit(info)