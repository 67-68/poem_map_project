class_name PropertyOperator extends BaseOperator

@export var _property: ENUMS.PROPS = ENUMS.PROPS.OFFICIAL_PRESTIGE
var property := '':
    get():
        return ENUMS.to_prop_str(_property)

@export var value: int = 0

func operate():
    PlayerState.change_stat(property,value)