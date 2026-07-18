@tool
class_name TraitRequirement extends BaseRequirements

@export var trait_name: String
@export var operator: REQ_OPERATOR.EXIST = REQ_OPERATOR.EXIST.HAS

func get_referenced_traits() -> Array:
    if trait_name.is_empty():
        return []
    return [trait_name]

func describe_requirement() -> String:
    if trait_name.is_empty():
        return ""
    var trait_obj = Database.get_trait(trait_name)
    var cn_name = trait_obj.name if trait_obj and not trait_obj.name.is_empty() else trait_name
    if operator == REQ_OPERATOR.EXIST.HAS:
        return tr("CODE_TRAIT_REQUIREMENT_7C2985A29D") % cn_name
    elif operator == REQ_OPERATOR.EXIST.NOT_HAS:
        return tr("CODE_TRAIT_REQUIREMENT_BFBF373707") % cn_name
    return ""

func compare(player_state) -> bool:
    if operator == REQ_OPERATOR.EXIST.HAS:
        return player_state.has_trait(trait_name)
    elif operator == REQ_OPERATOR.EXIST.NOT_HAS:
        return not player_state.has_trait(trait_name)
    return false
