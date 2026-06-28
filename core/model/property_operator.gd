class_name PropertyOperator extends BaseOperator

@export var _property: ENUMS.PROPS = -1
var property := """""":
    get():
        if str_props:
            return str_props
        Logging.warn("PropertyOperator: string property not set, use enum property")
        return ENUMS.to_prop_str(_property)
    set(value):
        str_props = value

@export var str_props: String = """"""
@export var value: int = 0
@export var context_key_for_multiplication: String = "property_multiplication"
