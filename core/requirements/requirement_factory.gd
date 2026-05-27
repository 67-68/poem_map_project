class_name RequirementFactory extends GDScript

# static func create_property_requirement():
#     var prop_req = PropertyRequirement.new()

static func create_flag_requirement(flag_id: String, type: String, value: Variant, operator: REQ_OPERATOR.COMPARE = REQ_OPERATOR.COMPARE.GREATER_THAN) -> FlagRequirement:
    var req = FlagRequirement.new()
    req.flag_id = flag_id
    req.type = type
    req.value = value
    req.operator = operator
    return req