class_name PropertyOperator extends StatOperator

@export var property := ''
@export var value: int = 0
@export var operator := '+'

func operate():
    if not value is int:
        Logging.err('propertyOperator: value %s of property %s is not a int' % [value,property])
    if operator == '+':
        PlayerState.change_stat(property,value)
    else:
        PlayerState.change_stat(property,-value)