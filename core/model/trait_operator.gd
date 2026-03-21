class_name TraitOperator extends StatOperator

@export var trait_key: PlayerState.Traits # refers to the trait in trait base
@export var operator := REQ_OPERATOR.CRUD.ADD

func operate():
    if operator == REQ_OPERATOR.CRUD.ADD:
        PlayerState.add_trait(PlayerState.get_trait_from_enum(trait_key))
    elif operator == REQ_OPERATOR.CRUD.REMOVE:
        PlayerState.remove_trait(PlayerState.get_trait_from_enum(trait_key))
    else:
        Logging.err('TraitOperator: unsupported operator %s for trait operations' % operator)