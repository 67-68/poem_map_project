@tool
class_name ForceSetPropertyOperator extends BaseOperator

## 强制设值属性，跳过 hard_max 检查
## 用于事件系统中需要突破属性上限的特殊场景

@export var _property: ENUMS.PROPS = ENUMS.PROPS.MONEY
var property: String:
	get():
		return ENUMS.to_prop_str(_property)

@export var value: int = 0

func operate() -> void:
	PlayerState.force_set_stat_val(property, value)
