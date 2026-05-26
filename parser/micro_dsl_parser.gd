class_name MicroDSLParser extends GDScript

# 解析触发标签格式：domain:subcategory:category:specific_attribute (4段)
static func parse_tags(data: String) -> Array[String]:
    var tags = data.split(',')
    var parsed_tags: Array[String] = []
    
    for tag in tags:
        var clean_tag = tag.strip_edges()
        if clean_tag.is_empty():
            continue
            
        # 验证标签格式 (domain:subcategory:category:specific_attribute)
        var parts = clean_tag.split(':')
        if parts.size() != 4:
            print("Warning: Invalid tag format: %s, expected format: domain:subcategory:category:specific_attribute" % clean_tag)
            continue
            
        parsed_tags.append(clean_tag)
    
    return parsed_tags

# 解析属性触发条件，如：prop:money:>50 或 prop:money:<50
static func parse_property_requirement(data: String) -> PropertyRequirement:
    var parts = data.split(':')
    if parts.size() != 3:
        push_error("Invalid property requirement format: %s, expected: prop:property_name:>value" % data)
        return null
    
    if parts[0] != "prop":
        push_error("Property requirement must start with 'prop:', got: %s" % data)
        return null
    
    var property_name = parts[1]
    var operator_str = parts[2]
    
    # 解析操作符和值
    if operator_str.begins_with('>'):
        var value = operator_str.substr(1).to_int()
        return create_property_requirement(property_name, value, REQ_OPERATOR.COMPARE.GREATER_THAN)
    elif operator_str.begins_with('<'):
        var value = operator_str.substr(1).to_int()
        return create_property_requirement(property_name, value, REQ_OPERATOR.COMPARE.LESS_THAN)
    else:
        push_error("Invalid operator in property requirement: %s, expected > or <" % operator_str)
        return null

# 解析特性触发条件，如：trait:has:official 或 trait:not_has:official
static func parse_trait_requirement(data: String) -> BaseRequirements:
    var parts = data.split(':')
    if parts.size() != 3:
        push_error("Invalid trait requirement format: %s, expected: trait:has/not_has:trait_name" % data)
        return null
    
    if parts[0] != "trait":
        push_error("Trait requirement must start with 'trait:', got: %s" % data)
        return null
    
    var operator = parts[1]
    var trait_name = parts[2]
    
    # 创建一个简单的特性检查需求（这里需要根据实际系统调整）
    # 由于现有系统没有直接的TraitRequirement，我们可能需要扩展或创建新的需求类
    if operator == "has":
        return create_trait_has_requirement(trait_name, true)
    elif operator == "not_has":
        return create_trait_has_requirement(trait_name, false)
    else:
        push_error("Invalid trait operator: %s, expected 'has' or 'not_has'" % operator)
        return null

# 解析结果操作符，如：prop:money:-100, trait:add:corrupt
static func parse_consequence_operators(data: String) -> Array[BaseOperator]:
    var operators: Array[BaseOperator] = []
    var parts = data.split(',')
    
    for part in parts:
        var clean_part = part.strip_edges()
        if clean_part.is_empty():
            continue
            
        var op_parts = clean_part.split(':')
        if op_parts.size() != 3:
            print("Warning: Invalid consequence operator format: %s, expected: type:action:value" % clean_part)
            continue
        
        var type = op_parts[0]
        var action = op_parts[1]
        var value = op_parts[2]
        
        if type == "prop":
            var operator = parse_property_operator(action, value)
            if operator:
                operators.append(operator)
        elif type == "trait":
            var operator = parse_trait_operator(action, value)
            if operator:
                operators.append(operator)
        elif type == "emo":
            var operator = parse_emotion_operator(action, value)
            if operator:
                operators.append(operator)
        else:
            print("Warning: Unknown consequence operator type: %s" % type)
    
    return operators

# 辅助方法：创建属性需求
static func create_property_requirement(property_name: String, value: int, operator: REQ_OPERATOR.COMPARE) -> PropertyRequirement:
    var req = PropertyRequirement.new()
    req.property = property_name
    req.value = value
    req.operator = operator
    return req

# 辅助方法：创建特性需求（需要根据实际系统实现）
static func create_trait_has_requirement(trait_name: String, _should_have: bool) -> BaseRequirements:
    # 这里需要根据实际的特性系统实现
    # 暂时返回一个基础需求，实际使用时需要扩展
    var req = TraitRequirement.new()
    req.trait_name = trait_name
    if _should_have:
        req.operator = REQ_OPERATOR.EXIST.HAS
    else:
        req.operator = REQ_OPERATOR.EXIST.NOT_HAS
    return req

# 辅助方法：解析属性操作符
static func parse_property_operator(action: String, value_str: String) -> BaseOperator:
    var value = value_str.to_int()
    var operator = PropertyOperator.new()
    
    # 根据属性名称设置对应的枚举值
    operator.str_props = action
    
    if value_str.begins_with('+') or value_str.begins_with('-'):
        operator.value = value
    
    return operator

# 辅助方法：解析特性操作符
static func parse_trait_operator(action: String, trait_name: String) -> BaseOperator:
    var operator = TraitOperator.new()
    
    if action == "add":
        operator.operator = REQ_OPERATOR.CRUD.ADD
    elif action == "remove":
        operator.operator = REQ_OPERATOR.CRUD.REMOVE
    else:
        print("Warning: Unknown trait action: %s, expected 'add' or 'remove'" % action)
        return null
    
    # 设置特性键（需要根据实际系统映射）
    operator.str_traits = trait_name
    
    return operator

# 辅助方法：解析情绪操作符
static func parse_emotion_operator(action: String, value_str: String) -> BaseOperator:
    var value = value_str.to_int()
    var operator = EmotionOperator.new()
    
    # 设置情绪名称
    operator.str_emotion = action
    
    # 设置数值（支持 +10 或 -10 格式）
    if value_str.begins_with('+') or value_str.begins_with('-'):
        operator.value = value
    
    return operator
