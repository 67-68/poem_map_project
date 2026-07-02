class_name ChoiceResult extends Resource

# target uuid 使用event operator
@export var operators: Array[BaseOperator]	 = []

func operate():
	"""
	执行所有操作符
	"""
	if not operators:
		Logging.warn('ChoiceResult.operate: operators is empty')
		return
	
	Logging.info('ChoiceResult.operate: executing %d operator(s)' % operators.size())
	for i in operators.size():
		var op = operators[i]
		if op:
			Logging.info('ChoiceResult.operate: operator[%d] = %s' % [i, op.get_class()])
			op.operate()
		else:
			Logging.warn('ChoiceResult.operate: operator[%d] is null, skipping' % i)

func init(context: Dictionary) -> Dictionary:
	if operators:
		for op in operators:
			if not op:
				Logging.err('theres a null operator in event choice result')
				continue
			op.init(context)
	return context

## Fluent builder: 追加一个 operator 并返回 self（用于 @export 默认值链式构造）
func append(op: BaseOperator) -> ChoiceResult:
	operators.append(op)
	return self

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
