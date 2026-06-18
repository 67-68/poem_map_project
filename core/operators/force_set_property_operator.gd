@tool
class_name ForceSetPropertyOperator extends BaseOperator

## 强制设值属性，跳过 hard_max 检查
## 用于事件系统中需要突破属性上限的特殊场景

@export var _property: ENUMS.PROPS = ENUMS.PROPS.MONEY
var property: String:
	get():
		return ENUMS.to_prop_str(_property)

@export var value: int = 0

func describe_preview() -> String:
	if property.is_empty():
		return ""
	var prop = Database.get_property(property)
	if not prop:
		return ""
	var cn_name = prop.name if not prop.name.is_empty() else property
	var target_perception = prop.get_staged_perception_at_threshold(value)
	return "%s → %s" % [cn_name, target_perception]

func operate() -> void:
	PlayerState.force_set_stat_val(property, value)
