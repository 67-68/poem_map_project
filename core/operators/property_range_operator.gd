
# 根据property的值在min_value和max_value之间来判断是否满足条件，执行operator

@export var min_value: float
@export var max_value: float
@export var _property: ENUMS.PROPS = ENUMS.PROPS.MONEY
var property: String:
	get():
		return ENUMS.to_prop_str(_property)

@export var result_operator: BaseOperator

func operate() -> void:
	if PlayerState.get(property) >= min_value and PlayerState.get(property) <= max_value:
		result_operator.operate()
