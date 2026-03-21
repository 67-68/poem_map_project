class_name TimeOperator extends StatOperator

@export var day: float

func operate():
	Global.year += float(day) / 365.0
	Logging.info('Time change by %s days, new year: %s' % [day, Global.year])