class_name DictMultiplyOperator extends GameEntity

# 存储所有乘法操作符的字典
var operators: Dictionary = {}

func _init(data = {}):
	super._init(data)
	if not data:
		return
	
	# 适配新的数据结构：{"operators": {...}}
	var operators_data = data.get("operators", data)
	
	for name_ in operators_data:
		var operator = MultiplyOperator.new(operators_data[name_])
		operators[name_] = operator

func match_and_multiply(prop_name: String, prop: int):
	var operator = operators.get(prop_name)
	if operator is MultiplyOperator:
		return operator.multiply(prop)
	else:
		Logging.error('somehow the prop name %s match with a sys prop name, change it' % prop_name)
		return

# 获取所有操作符名称
func get_operator_names() -> Array:
	return operators.keys()

# 检查是否包含指定操作符
func has_operator(name: String) -> bool:
	return operators.has(name)

# 获取指定操作符
func get_operator(name: String) -> MultiplyOperator:
	return operators.get(name)
