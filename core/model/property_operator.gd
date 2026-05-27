@tool
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
@export var context_key_for_multiplication: String = "property_multiplication"

func init(_context: Dictionary) -> Dictionary:
    if _context.has(context_key_for_multiplication):
        var ctx_val = _context[context_key_for_multiplication]
        if typeof(ctx_val) in [TYPE_FLOAT, TYPE_INT]:
            var original_value = value
            value = int(float(value) * float(ctx_val))
            Logging.debug("PropertyOperator: Multiplying value %d by context[%s]=%.2f → %d" % [original_value, context_key_for_multiplication, float(ctx_val), value])
        else:
            Logging.warn("PropertyOperator: context[%s] has unexpected type %s, skipping multiplication" % [context_key_for_multiplication, typeof(ctx_val)])
    else:
        Logging.debug("PropertyOperator: context key '%s' not found, no multiplication applied" % context_key_for_multiplication)
    return _context

func operate():
    PlayerState.append_stat(property,value)

func get_referenced_flags() -> Array:
    return []

func get_referenced_traits() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []

func get_demanded_traits() -> Array:
    return []