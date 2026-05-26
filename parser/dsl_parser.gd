class_name DSLParser extends GDScript

# 解析随机事件
static func parse_random_event(row: Dictionary) -> RandomEvent:
    # 检测空行
    if row.is_empty():
        return null

    # 检测所有值都为空的行
    var has_content = false
    for key in row:
        var value = row[key]
        if value != null and not str(value).is_empty():
            has_content = true
            break

    if not has_content:
        return null

    var event = RandomEvent.new()

    # 解析必需字段
    var event_id = row.get('event_id')
    if not event_id or event_id.is_empty():
        push_error("Event_ID is required")
        return null
    event.uuid = event_id

    # 解析触发标签
    var trigger_tags = row.get('trigger_tags')
    if not trigger_tags or trigger_tags.is_empty():
        print("Warning: trigger_tags is empty for event: %s" % event_id)
    event._target_tags = MicroDSLParser.parse_tags(trigger_tags)

    # 解析触发条件
    var requirements_str = row.get('requirements')
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)

    # 解析表现层
    event.name = row.get('title',"")
    event.description = row.get('description',"")

    # 解析选项
    event.options = parse_options(row)

    event.icon = parse_background(row.get('background', ""))

    # 解析权重（可选）
    var weight_str = row.get('weight')
    if weight_str and not weight_str.is_empty():
        event.weight = weight_str.to_float()

    return event

# 解析标志位数据
static func parse_flag(row: Dictionary) -> Flag:
    # 检测空行
    if row.is_empty():
        return null

    # 检测所有值都为空的行
    var has_content = false
    for key in row:
        var value = row[key]
        if value != null and not str(value).is_empty():
            has_content = true
            break

    if not has_content:
        return null

    var flag = Flag.new()

    # 解析必需字段 flag_id
    var flag_id = row.get('flag_id')
    if not flag_id or flag_id.is_empty():
        push_error("flag_id is required")
        return null
    flag.uuid = flag_id

    # 解析 type 字段
    var flag_type = row.get('type', 'str')
    if flag_type not in ['str', 'int', 'bool']:
        print("Warning: Invalid flag type '%s' for flag %s, defaulting to 'str'" % [flag_type, flag_id])
        flag_type = 'str'
    flag.type = flag_type

    # 解析 default_value 字段
    var default_value = row.get('default_value', '')
    match flag_type:
        'str':
            flag.val_str = str(default_value)
        'int':
            var int_val = str(default_value).to_int()
            flag.val_int = int_val
        'bool':
            var bool_str = str(default_value).to_lower()
            # 支持多种布尔值表示：true/false, t/f, 1/0, yes/no, TRUE/FALSE
            flag.val_bool = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
        _:
            print("Warning: Unknown flag type '%s', defaulting to str" % flag_type)
            flag.val_str = str(default_value)

    print("Flag解析成功: %s (type=%s, default=%s)" % [flag_id, flag_type, default_value])
    return flag

# 主要的CSV解析方法（保持向后兼容）
static func parse(row: Dictionary) -> RandomEvent:
    return parse_random_event(row)

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
    elif req_str.begins_with('flag:'):
        return MicroDSLParser.parse_flag_requirement(req_str)
    else:
        print("Warning: Unknown requirement type: %s" % req_str)
        return null

# 解析选项（1, 2, 3等）
static func parse_options(row: Dictionary) -> Array[BaseOption]:
    var options: Array[BaseOption] = []

    # 支持多个选项：1, 2, 3, 4等
    var option_numbers = ['1', '2', '3', '4', '5', '6']

    for number in option_numbers:
        var option = parse_option(row, number)
        if option:
            options.append(option)

    return options

# 解析单个选项
static func parse_option(row: Dictionary, letter: String) -> BaseOption:
    var text_key = "opt_%s_text" % letter
    var req_key = "opt_%s_requirement" % letter
    var result_key = "opt_%s_result" % letter

    var option_text = row.get(text_key)
    if not option_text or option_text.is_empty():
        return null
    
    var option = EventOption.new()
    option.description = option_text
    
    # 解析选项门槛
    var requirement_str = row.get(req_key)
    if requirement_str and not requirement_str.is_empty():
        option.requirements = parse_option_requirement(requirement_str)
    
    # 解析选项结果
    var result_str = row.get(result_key)
    if result_str and not result_str.is_empty():
        option.choice_result = parse_choice_result(result_str)
    
    # 解析情绪配置
    var emotion_config_key = "opt_%s_emotion_config" % letter
    var emotion_config_str = row.get(emotion_config_key)
    if emotion_config_str and not emotion_config_str.is_empty():
        option.emotion_configs = parse_emotion_configs(emotion_config_str)
    
    return option

# 解析选项门槛（简化版，只支持属性检查）
static func parse_option_requirement(req_str: String) -> BaseRequirements:
    if req_str.begins_with('prop:'):
        return MicroDSLParser.parse_property_requirement(req_str)
    elif req_str.begins_with('trait:'):
        return MicroDSLParser.parse_trait_requirement(req_str)
    elif req_str.begins_with('flag:'):
        return MicroDSLParser.parse_flag_requirement(req_str)
    else:
        print("Warning: Unknown option requirement type: %s" % req_str)
        return null

# 解析选择结果
static func parse_choice_result(result_str: String) -> ChoiceResult:
    var choice_result = ChoiceResult.new()
    choice_result.operators = MicroDSLParser.parse_consequence_operators(result_str)
    return choice_result

# 解析情绪配置（支持多个配置，用分号分隔）
# 语法格式：imaginary_name <- condA&condB | condC;imaginary_name2 <- condD
# 先处理 | (OR)，然后处理 & (AND)
static func parse_emotion_configs(emotion_config_str: String) -> Array[EmotionConfigs]:
    var emotion_configs: Array[EmotionConfigs] = []
    
    # 分割多个配置（用分号分隔）
    var config_parts = emotion_config_str.split(';')
    if config_parts.is_empty():
        print("Warning: Empty emotion_config")
        return []
    
    for config_str in config_parts:
        var clean_config = config_str.strip_edges()
        if clean_config.is_empty():
            continue
        
        var emotion_config = parse_single_emotion_config(clean_config)
        if emotion_config:
            emotion_configs.append(emotion_config)
    
    return emotion_configs

# 解析单个情绪配置
# 语法格式：imaginary_name <- condA&condB | condC
static func parse_single_emotion_config(config_str: String) -> EmotionConfigs:
    var emotion_config = EmotionConfigs.new()
    
    # 解析配置：imaginary_name <- conditions
    var config_parts = config_str.split('<-')
    if config_parts.size() != 2:
        print("Warning: Invalid emotion_config format, expected 'imaginary_name <- conditions': %s" % config_str)
        return null
    
    var imaginary_name = config_parts[0].strip_edges()
    var conditions_str = config_parts[1].strip_edges()
    
    # 设置目标意象（从字符串映射到ImaginaryTag对象）
    emotion_config.target_imagenary_blueprint = get_imaginary_from_name(imaginary_name)
    if not emotion_config.target_imagenary_blueprint:
        print("Warning: Could not find imaginary: %s" % imaginary_name)
        return null
    
    # 解析条件：先处理 | (OR)，然后处理 & (AND)
    var or_groups = conditions_str.split('|')
    var all_requirements: Array[BaseRequirements] = []
    
    for or_group in or_groups:
        var clean_or_group = or_group.strip_edges()
        if clean_or_group.is_empty():
            continue
        
        # 处理 & (AND) 组
        var and_conditions = clean_or_group.split('&')
        var and_requirements: Array[BaseRequirements] = []
        
        for condition in and_conditions:
            var clean_condition = condition.strip_edges()
            if clean_condition.is_empty():
                continue
            
            var requirement = parse_single_emotion_condition(clean_condition)
            if requirement:
                and_requirements.append(requirement)
        
        # 如果AND组有多个条件，创建复合需求
        if and_requirements.size() == 1:
            all_requirements.append(and_requirements[0])
        elif and_requirements.size() > 1:
            var complex_req = ComplexRequirements.new()
            complex_req.operators = and_requirements
            complex_req.current_operator = REQ_OPERATOR.LOGIC.AND
            all_requirements.append(complex_req)
    
    # 如果有多个OR组，创建OR逻辑
    if all_requirements.size() == 1:
        emotion_config.requirements = all_requirements
    elif all_requirements.size() > 1:
        var or_complex_req = ComplexRequirements.new()
        or_complex_req.operators = all_requirements
        or_complex_req.current_operator = REQ_OPERATOR.LOGIC.OR
        emotion_config.requirements = [or_complex_req]
    
    return emotion_config

# 辅助方法：从名字获取ImaginaryTag对象
static func get_imaginary_from_name(imaginary_name: String) -> ImaginaryTag:
    # 尝试直接作为两段式UUID
    var imaginary = Database.imaginaries.get(imaginary_name)
    if imaginary:
        return imaginary as ImaginaryTag
    
    # 如果是四段式，尝试映射到两段式
    var parts = imaginary_name.split(':')
    if parts.size() == 4:
        # 假设格式：domain:subcategory:category:specific_attribute
        # 映射到两段式：subcategory:category
        var two_part_uuid = parts[1] + ':' + parts[2]
        imaginary = Database.imaginaries.get(two_part_uuid)
        if imaginary:
            return imaginary as ImaginaryTag
    
    print("Warning: Could not map imaginary_name '%s' to ImaginaryTag" % imaginary_name)
    return null

# 解析单个情绪条件
static func parse_single_emotion_condition(condition: String) -> BaseRequirements:
    # 支持情绪条件：emotion:sorrow:>10
    if condition.begins_with('emotion:'):
        var parts = condition.substr(8).split(':')  # 去掉"emotion:"前缀
        if parts.size() == 2:
            var emotion_name = parts[0]
            var operator_str = parts[1]

            var emotion_req = EmotionRequirement.new()
            emotion_req.volatile_stat = emotion_name

            if operator_str.begins_with('>'):
                emotion_req.value = operator_str.substr(1).to_int()
                emotion_req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
            elif operator_str.begins_with('<'):
                emotion_req.value = operator_str.substr(1).to_int()
                emotion_req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
            else:
                # 默认为大于
                emotion_req.value = operator_str.to_int()
                emotion_req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN

            return emotion_req

    # 支持属性条件：prop:money:>50
    elif condition.begins_with('prop:'):
        return MicroDSLParser.parse_property_requirement(condition)

    # 支持特性条件：trait:has:official
    elif condition.begins_with('trait:'):
        return MicroDSLParser.parse_trait_requirement(condition)

    # 支持标志位条件：flag:bool:has:xxx
    elif condition.begins_with('flag:'):
        return MicroDSLParser.parse_flag_requirement(condition)

    print("Warning: Unknown condition type: %s" % condition)
    return null

# 验证解析结果
static func validate_event(event: RandomEvent) -> bool:
    if not event:
        return false

    if not event.uuid or event.uuid.is_empty():
        push_error("Event validation failed: missing ID")
        return false

    if event.options.is_empty():
        print("Warning: Event validation warning: no options for event %s" % event.uuid)

    if event.icon == null:
        print("Warning: Event validation warning: no icon for event %s" % event.uuid)

    return true

# 验证 Flag 解析结果
static func validate_flag(flag: Flag) -> bool:
    if not flag:
        return false

    if not flag.uuid or flag.uuid.is_empty():
        push_error("Flag validation failed: missing ID")
        return false

    if flag.type.is_empty():
        print("Warning: Flag validation warning: no type for flag %s" % flag.uuid)
        return false

    if flag.type not in ['str', 'int', 'bool']:
        print("Warning: Flag validation warning: invalid type '%s' for flag %s" % [flag.type, flag.uuid])
        return false

    return true

# 批量解析CSV数据
static func parse_csv_data(csv_data: Array[Dictionary], data_type: String = "random_event") -> Array[Resource]:
    var resources: Array[Resource] = []

    for i in range(csv_data.size()):
        var row = csv_data[i]
        var resource: Resource = null

        if data_type == "random_event":
            var event = parse_random_event(row)
            if event and validate_event(event):
                resource = event
            else:
                print("Warning: Failed to parse event at row %d" % (i + 1))
        elif data_type == "flags":
            var flag = parse_flag(row)
            if flag and validate_flag(flag):
                resource = flag
            else:
                print("Warning: Failed to parse flag at row %d" % (i + 1))
        else:
            push_error("未知的 data_type: %s 💀" % data_type)
            continue

        if resource:
            resources.append(resource)

    return resources
