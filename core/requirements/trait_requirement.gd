@tool
class_name TraitRequirement extends BaseRequirements

@export var trait_name: String
@export var operator: REQ_OPERATOR.EXIST = REQ_OPERATOR.EXIST.HAS

func get_referenced_traits() -> Array:
    if trait_name.is_empty():
        return []
    return [trait_name]

func compare(player_state) -> bool:
    if operator == REQ_OPERATOR.EXIST.HAS:
        return player_state.has_trait(trait_name)
    elif operator == REQ_OPERATOR.EXIST.NOT_HAS:
        return not player_state.has_trait(trait_name)
    return false
