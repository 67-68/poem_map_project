class_name OperatorFactory extends GDScript

static func create_event_operator(event_key) -> EventOperator:
    var operator := EventOperator.new()
    operator.event_key = event_key
    return operator

static func create_property_operator(property_name: String, value: float) -> PropertyOperator:
    var operator := PropertyOperator.new()
    operator.property = property_name
    operator.value = value
    return operator

static func create_flag_operator(flag_id: String, type: String, value: Variant, operation: String = 'set') -> FlagOperator:
    var operator := FlagOperator.new()
    operator.flag_id = flag_id
    operator.type = type
    operator.value = value
    operator.operation = operation
    return operator
