class_name TraitOperator extends StatOperator

func _init(data):
    super._init(data)

func operate():
    if not value is String:
        Logging.err('TraitOperator: value %s of key %s is not a String' % [value, key])
        return
    
    if operator == '+':
        PlayerState.add_trait(value)
    elif operator == '-':
        PlayerState.remove_trait(value)
    else:
        Logging.err('TraitOperator: unsupported operator %s for trait operations' % operator)
