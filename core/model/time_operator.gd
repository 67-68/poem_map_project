class_name TimeOperator extends StatOperator

@export var day: float

func operate():
	TimeService.jump_to(day/365)
	Logging.info('Time change by %s days, new year: %s' % [day, Global.year])