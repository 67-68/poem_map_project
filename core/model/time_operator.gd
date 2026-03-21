class_name TimeOperator extends StatOperator

@export var day: float
@export var operator := '+'

func operate():
	"""
	执行时间推进操作
	"""
	if day <= 0:
		Logging.warn('TimeOperator: day %s is not positive' % day)
		return
	
	Global.year += float(day) / 365.0
	Logging.info('Time advanced by %s days, new year: %s' % [day, Global.year])
