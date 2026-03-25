class_name TraitOperator extends BaseOperator

@export var _trait_key: ENUMS.TRAITS # refers to the trait in trait base
var trait_key: String:
    get():
        return ENUMS.to_traits_str(_trait_key)
@export var operator := REQ_OPERATOR.CRUD.ADD

func operate():
    if operator == REQ_OPERATOR.CRUD.ADD:
        PlayerState.add_trait(trait_key)
    elif operator == REQ_OPERATOR.CRUD.REMOVE:
        PlayerState.remove_trait(trait_key)
    else:
        Logging.err('TraitOperator: unsupported operator %s for trait operations' % operator)