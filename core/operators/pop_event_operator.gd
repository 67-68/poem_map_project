@tool
class_name PopEventOperator extends BaseOperator

func operate():
	Logging.info("PopEventOperator: Popping event from stack")
	EventBus.pop_event.emit()
