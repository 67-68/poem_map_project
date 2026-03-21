class_name ChoiceResult extends GameEntity

@export var target_uuid: String = ''
@export var action_type: String = ''
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
