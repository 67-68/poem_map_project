@tool
class_name PropRangeRequirement extends BaseRequirements

@export var min_value: float
@export var max_value: float
@export var _property: ENUMS.PROPS = ENUMS.PROPS.MONEY
var property: String:
	get():
		return ENUMS.to_prop_str(_property)

func describe_requirement() -> String:
	if property.is_empty():
		return ""
	var prop = Database.get_property(property)
	if not prop:
		return ""
	var min_text = prop.get_staged_perception_at_threshold(int(min_value))
	if min_text.is_empty() or min_text == tr("CODE_RANGE_REQUIREMENT_EC0D9BDB00"):
		return ""
	return tr("CODE_RANGE_REQUIREMENT_B0E2EB548E") % [int(min_value), min_text]

func compare(player_state) -> bool:
	return player_state.get_stat_val(property) >= min_value and player_state.get_stat_val(property) <= max_value
