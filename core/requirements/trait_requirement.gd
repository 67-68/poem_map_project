class_name TraitRequirement extends BaseRequirements

@export var trait_name: String
@export var operator: REQ_OPERATOR.EXIST = REQ_OPERATOR.EXIST.HAS

func compare(player_state) -> bool:
    if operator == REQ_OPERATOR.EXIST.HAS:
        return player_state.has_trait(trait_name)
    elif operator == REQ_OPERATOR.EXIST.NOT_HAS:
        return not player_state.has_trait(trait_name)
    return false