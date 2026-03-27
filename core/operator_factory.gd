class_name OperatorFactory extends GDScript

static func create_event_operator(event_key) -> EventOperator:
    var operator := EventOperator.new()
    operator.event_key = event_key
    return operator
