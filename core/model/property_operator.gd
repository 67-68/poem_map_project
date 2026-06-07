@tool
class_name PropertyOperator extends BaseOperator

@export var _property: ENUMS.PROPS = -1
var property := '':
    get():
        if str_props:
            return str_props
        Logging.warn("PropertyOperator: string property not set, use enum property")
        return ENUMS.to_prop_str(_property)
    set(value):
        str_props = value

@export var str_props: String = ""
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
    Logging.debug("PropertyOperator.operate: property=%s, value=%d" % [property, value])
    PlayerState.append_stat(property, value)
    
    # ── 飘字反馈：属性变化后 emit 模糊文本 ──
    _emit_float_text(value)

func _emit_float_text(delta: int) -> void:
    Logging.debug("PropertyOperator._emit_float_text: property=%s, delta=%d" % [property, delta])
    if delta == 0:
        Logging.debug("PropertyOperator._emit_float_text: delta=0, skip")
        return
    var prop = Database.properties.get(property)
    if not prop:
        Logging.err("PropertyOperator._emit_float_text: property '%s' not found in Database" % property)
        return
    var perception_text = prop.get_change_perception_text(delta)
    Logging.debug("PropertyOperator._emit_float_text: get_change_perception_text(%d) -> '%s'" % [delta, perception_text])
    if perception_text.is_empty():
        Logging.debug("PropertyOperator._emit_float_text: perception_text is empty, skip")
        return
    
    # FloatingText 现在使用 Control 自动定位到屏幕顶部居中
    Logging.debug("PropertyOperator._emit_float_text: emitting request_float_text('%s')" % perception_text)
    EventBus.request_float_text.emit(perception_text)

func get_referenced_flags() -> Array:
    return []

func get_referenced_traits() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []

func get_demanded_traits() -> Array:
    return []