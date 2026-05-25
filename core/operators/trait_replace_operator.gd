class_name TraitReplaceOperator extends BaseOperator

@export var _replace_other_trait: ENUMS.TRAITS
@export var _to_be_replaced_trait: ENUMS.TRAITS
var replace_other_trait: String:
    get():
        return ENUMS.to_traits_str(_replace_other_trait)
var to_be_replaced_trait: String:
    get():
        return ENUMS.to_traits_str(_to_be_replaced_trait)
    
func operate():
    Logging.debug('TraitReplaceOperator: Starting operate()')
    PlayerState.remove_trait(to_be_replaced_trait)
    PlayerState.add_trait(replace_other_trait)