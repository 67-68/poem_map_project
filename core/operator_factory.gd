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

static func create_trait_operator(trait_key: Variant) -> TraitOperator:
    var operator := TraitOperator.new()
    if typeof(trait_key) == TYPE_STRING:
        operator.str_traits = trait_key
    else:
        operator._trait_key = trait_key
    return operator

static func create_flag_operator(flag_id: String, type: String, value: Variant, operation: String = 'set') -> FlagOperator:
    var operator := FlagOperator.new()
    operator.flag_id = flag_id
    operator.type = type
    operator.value = value
    operator.operation = operation
    return operator

static func create_flag_replace_operator(to_be_replaced_flag_id: String, replace_with_flag_id: String) -> FlagReplaceOperator:
    var operator := FlagReplaceOperator.new()
    operator.to_be_replaced_flag_id = to_be_replaced_flag_id
    operator.replace_with_flag_id = replace_with_flag_id
    return operator

static func create_push_event_operator(event_key: String) -> PushEventOperator:
    var operator := PushEventOperator.new()
    operator.event_key = event_key
    return operator
