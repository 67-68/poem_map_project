class_name ChoiceResult extends Resource

# target uuid 使用event operator
@export var operators: Array[BaseOperator] = []

func operate():
	"""
	执行所有操作符
	"""
	if not operators:
		Logging.warn('Found null operator in ChoiceResult')
	for op in operators:
		if op:
			op.operate()
		else:
			Logging.warn('Found null operator in ChoiceResult')

func init(context: Dictionary) -> Dictionary:
	if operators:
		for op in operators:
			op.init(context)
	return context