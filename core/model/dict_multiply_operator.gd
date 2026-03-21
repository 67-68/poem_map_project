class_name DictMultiplyOperator extends GameEntity

# 存储所有乘法操作符的字典
@export var operators: Array[OperatorEntry] = []

func _init(data = {}):
	super._init(data)
	if not data:
		return
	
	# 适配新的数据结构：{"operators": {...}}
	var operators_data = data.get("operators", data)
	
	for name_ in operators_data:
		var operator = MultiplyOperator.new(operators_data[name_])
		var entry = OperatorEntry.new()
		entry.name = name_
		entry.operator = operator
		operators.append(entry)

func match_and_multiply(prop_name: String, prop: int):
	for entry in operators:
		if entry.name == prop_name:
			return entry.operator.multiply(prop)
	Logging.error('somehow the prop name %s match with a sys prop name, change it' % prop_name)
	return

# 获取所有操作符名称
func get_operator_names() -> Array:
	var names = []
	for entry in operators:
		names.append(entry.name)
	return names

# 检查是否包含指定操作符
func has_operator(name: String) -> bool:
	for entry in operators:
		if entry.name == name:
			return true
	return false

# 获取指定操作符
func get_operator(name: String) -> MultiplyOperator:
	for entry in operators:
		if entry.name == name:
			return entry.operator
	return null
