class_name TraitOperator extends StatOperator

@export var trait_key: String # refers to the trait in trait base
@export var operator := '+'

func operate():
    if operator == '+':
        PlayerState.add_trait(trait_key)
    elif operator == '-':
        PlayerState.remove_trait(trait_key)
    else:
        Logging.err('TraitOperator: unsupported operator %s for trait operations' % operator)