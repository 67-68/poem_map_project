class_name ChoiceResult extends Resource

# target uuid 使用event operator
@export var operators: Array[BaseOperator] = []

func operate():
	"""
	执行所有操作符
	"""
	#breakpoint
	if not operators:
		#breakpoint
		Logging.warn('Found null operator in ChoiceResult')
	for op in operators:
		if op:
			op.operate()
		else:
			Logging.warn('Found null operator in ChoiceResult')

func init(context: Dictionary) -> Dictionary:
	if operators:
		for op in operators:
			if not op:
				Logging.err('theres a null operator in event choice result')
				continue
			op.init(context)
	return context

## 聚合所有 operator 的 describe_preview() 文本，过滤空字符串
func format_preview() -> Array[String]:
	var lines: Array[String] = []
	if not operators or operators.is_empty():
		return lines
	for op in operators:
		if not op:
			continue
		var text = op.describe_preview()
		if not text.is_empty():
			lines.append(text)
	return lines
