class_name PropertyOperator extends StatOperator

func _init(data):
    super._init(data)

func operate():
    if not value is int:
        Logging.err('propertyOperator: value %s of key %s is not a int' % [value,key])
    if operator == '+':
        PlayerState.change_stat(key,value)
    else:
        PlayerState.change_stat(key,-value)