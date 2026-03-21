class_name TimeOperator extends StatOperator

func _init(data):
	super._init(data)

func operate():
	"""
	执行时间推进操作
	"""
	if not value is float and not value is int:
		Logging.warn('TimeOperator: value %s is not a number' % value)
		return
	
	if value <= 0:
		Logging.warn('TimeOperator: value %s is not positive' % value)
		return
	
	Global.year += float(value) / 365.0
	Logging.info('Time advanced by %s days, new year: %s' % [value, Global.year])
