class_name PropRangeRequirement extends BaseRequirements

@export var min_value: float
@export var max_value: float
@export var _property: ENUMS.PROPS = ENUMS.PROPS.MONEY
var property: String:
	get():
		return ENUMS.to_prop_str(_property)

func compare(player_state) -> bool:
	return player_state.get(property) >= min_value and player_state.get(property) <= max_value
