class_name PropertyOperator extends BaseOperator

@export var _property: ENUMS.PROPS = ENUMS.PROPS.OFFICIAL_PRESTIGE
var property := '':
    get():
        if str_props:
            return str_props
        Logging.warn("PropertyOperator: string property not set, use enum property")
        return ENUMS.to_prop_str(_property)
    set(value):
        str_props = value

var str_props: String = ""
@export var value: int = 0

func operate():
    PlayerState.change_stat(property,value)