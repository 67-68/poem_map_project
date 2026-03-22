class_name TimeOperator extends StatOperator

@export var day: float

func operate():
	TimeService.advance_time(day/360)
	Logging.info('Time change by %s days, new year: %s' % [day, Global.year])