class_name ChoiceResult extends Resource

@export var target_event_uuid: String = ''
@export var operators: Array[StatOperator] = []

func operate():
	"""
	执行所有操作符
	"""
	for op in operators:
		if op:
			op.operate()
		else:
			Logging.warn('Found null operator in ChoiceResult')
