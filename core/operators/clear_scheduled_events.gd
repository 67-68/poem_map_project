@tool
class_name ClearScheduledEvents extends BaseOperator

func operate():
	Logging.info("ClearScheduledEvents: Clearing all scheduled events (stack + queue)")
	EventBus.clear_scheduled_events.emit()
