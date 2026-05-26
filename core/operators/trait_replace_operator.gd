class_name TraitReplaceOperator extends BaseOperator

@export var _replace_other_trait: ENUMS.TRAITS
@export var _to_be_replaced_trait: ENUMS.TRAITS
var replace_other_trait: String:
    get():
        if _replace_other_trait != null:
            return ENUMS.to_traits_str(_replace_other_trait)
        Logging.err("TraitReplaceOperator: _replace_other_trait is null!")
        return ""
var to_be_replaced_trait: String:
    get():
        if _to_be_replaced_trait != null:
            return ENUMS.to_traits_str(_to_be_replaced_trait)
        Logging.err("TraitReplaceOperator: _to_be_replaced_trait is null!")
        return ""

func get_referenced_traits() -> Array[String]:
    var result = []
    if not to_be_replaced_trait.is_empty():
        result.append(to_be_replaced_trait)
    return result

func get_provided_traits() -> Array[String]:
    var result = []
    if not replace_other_trait.is_empty():
        result.append(replace_other_trait)
    return result

func operate():
    Logging.debug('TraitReplaceOperator: Starting operate()')
    PlayerState.remove_trait(to_be_replaced_trait)
    PlayerState.add_trait(replace_other_trait)