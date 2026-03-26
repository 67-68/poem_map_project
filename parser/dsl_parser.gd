class_name DSLParser extends GDScript

# 主要的CSV解析方法，接受一行CSV数据并返回RandomEvent
static func parse(row: Dictionary) -> RandomEvent:
    var event = RandomEvent.new()
    
    # 解析必需字段
    var event_id = row.get('Event_ID')
    if not event_id or event_id.is_empty():
        Logging.err("Event_ID is required")
        return null
    event.uuid = event_id
    
    # 解析触发标签
    var trigger_tags = row.get('Trigger_Tags')
    if not trigger_tags or trigger_tags.is_empty():
        Logging.warn("Trigger_Tags is empty for event: %s" % event_id)
    event._target_tags = MicroDSLParser.parse_tags(trigger_tags)
    
    # 解析触发条件
    var requirements_str = row.get('requirements')
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)
    
    # 解析表现层
    event.name = row.get('Title',"")
    event.description = row.get('Desc',"")
    
    # 解析选项
    event.options = parse_options(row)

    event.icon = parse_background(row.get('background', ""))
    
    # 解析权重（可选）
    var weight_str = row.get('weight')
    if weight_str and not weight_str.is_empty():
        event.weight = weight_str.to_float()
    
    return event

static func parse_background(bg: String) -> Texture2D:
    if bg.is_empty():
        return null
    return TextureResLoader.get_background(bg)

# 解析触发条件，支持多个条件的AND组合
static func parse_requirements(requirements_str: String) -> BaseRequirements:
    var requirements = requirements_str.split(',')
    var parsed_requirements: Array[BaseRequirements] = []
    
    for req_str in requirements:
        var clean_req = req_str.strip_edges()
        if clean_req.is_empty():
            continue
            
        var requirement = parse_single_requirement(clean_req)
        if requirement:
            parsed_requirements.append(requirement)
    
    if parsed_requirements.is_empty():
        return null
    elif parsed_requirements.size() == 1:
        return parsed_requirements[0]
    else:
        # 创建复合需求（AND逻辑）
        var complex_req = ComplexRequirements.new()
        complex_req.operators = parsed_requirements
        complex_req.current_operator = REQ_OPERATOR.LOGIC.AND
        return complex_req

# 解析单个触发条件
static func parse_single_requirement(req_str: String) -> BaseRequirements:
    if req_str.begins_with('prop:'):
        return MicroDSLParser.parse_property_requirement(req_str)
    elif req_str.begins_with('trait:'):
        return MicroDSLParser.parse_trait_requirement(req_str)
    else:
        Logging.warn("Unknown requirement type: %s" % req_str)
        return null

# 解析选项（A, B, C等）
static func parse_options(row: Dictionary) -> Array[EventOption]:
    var options: Array[EventOption] = []
    
    # 支持多个选项：A, B, C, D等
    var option_letters = ['A', 'B', 'C', 'D', 'E', 'F']
    
    for letter in option_letters:
        var option = parse_option(row, letter)
        if option:
            options.append(option)
    
    return options

# 解析单个选项
static func parse_option(row: Dictionary, letter: String) -> EventOption:
    var text_key = "Opt_%s_Text" % letter
    var req_key = "Opt_%s_Req" % letter
    var result_key = "Opt_%s_Result" % letter
    
    var option_text = row.get(text_key)
    if not option_text or option_text.is_empty():
        return null
    
    var option = EventOption.new()
    option.description = option_text
    
    # 解析选项门槛
    var requirement_str = row.get(req_key)
    if requirement_str and not requirement_str.is_empty():
        option.property_requirement = parse_option_requirement(requirement_str)
    
    # 解析选项结果
    var result_str = row.get(result_key)
    if result_str and not result_str.is_empty():
        option.choice_result = parse_choice_result(result_str)
    
    return option

# 解析选项门槛（简化版，只支持属性检查）
static func parse_option_requirement(req_str: String) -> PropertyRequirement:
    if req_str.begins_with('prop:'):
        return MicroDSLParser.parse_property_requirement(req_str)
    elif req_str.begins_with('trait:'):
        return MicroDSLParser.parse_trait_requirement(req_str)
    else:
        Logging.warn("Unknown option requirement type: %s" % req_str)
        return null

# 解析选择结果
static func parse_choice_result(result_str: String) -> ChoiceResult:
    var choice_result = ChoiceResult.new()
    choice_result.operators = MicroDSLParser.parse_consequence_operators(result_str)
    return choice_result

# 验证解析结果
static func validate_event(event: RandomEvent) -> bool:
    if not event:
        return false
    
    if not event.uuid or event.uuid.is_empty():
        Logging.err("Event validation failed: missing ID")
        return false
    
    if event.options.is_empty():
        Logging.warn("Event validation warning: no options for event %s" % event.uuid)
    
    return true

# 批量解析CSV数据
static func parse_csv_data(csv_data: Array[Dictionary]) -> Array[RandomEvent]:
    var events: Array[RandomEvent] = []
    
    for i in range(csv_data.size()):
        var row = csv_data[i]
        var event = parse(row)
        if event and validate_event(event):
            events.append(event)
        else:
            Logging.warn("Failed to parse event at row %d" % (i + 1))
    
    return events
