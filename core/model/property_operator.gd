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
    # 动态解析 str_props -> _property enum（优先使用 str 属性）
    if not str_props.is_empty():
        var found := false
        for i in ENUMS.PROPS.size():
            if ENUMS.PROPS.keys()[i].to_lower() == str_props.to_lower():
                _property = i
                found = true
                break
        if not found:
            Logging.warn("PropertyOperator.init: str_props '%s' 无法解析为 PROPS 枚举" % str_props)

    if _context.has(context_key_for_multiplication):
        var ctx_val = _context[context_key_for_multiplication]
        if typeof(ctx_val) in [TYPE_FLOAT, TYPE_INT]:
            var original_value = value
            value = int(float(value) * float(ctx_val))
            Logging.debug("PropertyOperator: Multiplying value %d by context[%s]=%.2f -> %d" % [original_value, context_key_for_multiplication, float(ctx_val), value])
        else:
            Logging.warn("PropertyOperator: context[%s] has unexpected type %s, skipping multiplication" % [context_key_for_multiplication, typeof(ctx_val)])
    else:
        Logging.debug("PropertyOperator: context key '%s' not found, no multiplication applied" % context_key_for_multiplication)
    return _context

func operate():
    Logging.debug("PropertyOperator.operate: property=%s, value=%d" % [property, value])
    PlayerState.append_stat(property, value)
    _emit_float_text(value)

func _emit_float_text(delta: int) -> void:
    Logging.debug("PropertyOperator._emit_float_text: property=%s, delta=%d" % [property, delta])
    if delta == 0:
        Logging.debug("PropertyOperator._emit_float_text: delta=0, skip")
        return
    var prop = Database.get_property(property)
    if not prop:
        Logging.err("PropertyOperator._emit_float_text: property '%s' not found in Database" % property)
        return
    var perception_text = prop.get_change_perception_text(delta)
    Logging.debug("PropertyOperator._emit_float_text: get_change_perception_text(%d) -> '%s'" % [delta, perception_text])
    if perception_text.is_empty():
        Logging.debug("PropertyOperator._emit_float_text: perception_text is empty, skip")
        return
    Logging.debug("PropertyOperator._emit_float_text: emitting request_float_text('%s')" % perception_text)
    EventBus.request_float_text.emit(perception_text)

func describe_preview() -> String:
    if value == 0 or property.is_empty():
        return ""
    var prop = Database.get_property(property)
    if not prop:
        return ""
    var cn_name = prop.get_display_name() if not prop.name.is_empty() else property
    var arrow_char = "↑" if value > 0 else "↓"
    var arrow_count = _get_arrow_count(property, value)
    var arrows = ""
    for i in arrow_count:
        arrows += arrow_char
    return "%s %s" % [cn_name, arrows]

## 查 named_amounts.json 找最近 S/M/L 档位，返回箭头数量（1-3）
## 无匹配时返回 1（纯方向箭头）
static func _get_arrow_count(prop_name: String, delta: int) -> int:
    var amounts = NamedDSLParser._load_named_amounts()
    if amounts.is_empty():
        return 1

    var abs_val = abs(delta)
    var is_positive = delta > 0
    var prop_lower = prop_name.to_lower()

    # 过滤同号且包含 property 名的条目，记录绝对值
    var candidates: Array[Dictionary] = []
    for key in amounts:
        var entry_val = amounts[key]
        if (is_positive and entry_val > 0) or (not is_positive and entry_val < 0):
            if key.contains(prop_lower):
                candidates.append({"key": key, "abs": abs(entry_val)})

    if candidates.is_empty():
        return 1

    # 找绝对值最接近的
    var best_abs = candidates[0]["abs"]
    var best_key = candidates[0]["key"]
    var min_diff = abs(abs_val - best_abs)
    for c in candidates:
        var diff = abs(abs_val - c["abs"])
        if diff < min_diff:
            min_diff = diff
            best_abs = c["abs"]
            best_key = c["key"]

    # 从 key 前缀判断 S/M/L
    if best_key.begins_with("l_"):
        return 3
    elif best_key.begins_with("m_"):
        return 2
    else:  # s_ or anything else
        return 1

func get_referenced_flags() -> Array:
    return []

func get_referenced_traits() -> Array:
    return []

func get_demanded_flags() -> Array:
    return []

func get_demanded_traits() -> Array:
    return []