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
