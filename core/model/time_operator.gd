class_name TimeOperator extends StatOperator

@export var day: float
@export var source_tags: Array[String] = []

func operate():
	PlayerState.current_action_tags = source_tags
	TimeService.advance_time(int(day))
	Logging.info('Time change by %s days, new year: %s' % [day, Global.year])
	PlayerState.current_action_tags.clear()