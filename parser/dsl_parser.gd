class_name DSLParser extends GDScript

# ---------- 下推自动机辅助 ----------
# 从 row 中提取深度标记（第一列的值，全为 > 字符）
# 返回深度值：> → 1, >> → 2, >>> → 3
static func _get_row_depth(row: Dictionary) -> int:
    for key in row:
        var val = row[key]
        if val is String and not val.is_empty():
            var all_gt = true
            for c in val:
                if c != '>':
                    all_gt = false
                    break
            if all_gt:
                return val.length()
    return 0

# 解析 context DSL 字段
# 语法格式（用 | 分隔字段，避免与 tag 内部的逗号冲突）：
#   tag:tagA:sub:cat:attr,tagB:sub:cat:attr|weight:15.5|background:(bg_rural_poor)|customKey:customValue
# 也支持 = 作为 kv 分隔符（文档推荐格式）：
#   trigger_tags=[tagA:sub:cat:attr,tagB:sub:cat:attr]|weight=15.5|background=bg_rural_poor
# 已知字段:
#   tag / trigger_tags -> 触发标签列表（支持 [tag1,tag2] 方括号语法）
#   weight             -> 权重（float）
#   background         -> 背景图 URN
#   其他 key:value     -> 自定义模板参数
static func parse_context(context_str: String) -> Dictionary:
    var result = {
        "trigger_tags": [] as Array[String],  # 🚨 必须用类型化 Array，否则 Godot 4 拒绝赋值给 Array[String] 变量
        "weight": 10.0,
        "background": "",
        "custom_params": {}
    }
    
    if context_str.is_empty():
        return result
    
    # 用 | 作为字段分隔符，避免与 tag 内部的逗号冲突
    var fields = context_str.split("|")
    for field in fields:
        field = field.strip_edges()
        if field.is_empty():
            continue
        
        # 优先用 = 作为 kv 分隔符（文档推荐格式），fallback 到 :（旧格式兼容）
        var eq_idx = field.find("=")
        var colon_idx = field.find(":")
        var kv_split = -1
        if eq_idx != -1:
            kv_split = eq_idx
        elif colon_idx != -1:
            kv_split = colon_idx
        else:
            print("Warning: Context 字段缺少分隔符 (= 或 :): %s" % field)
            continue
        
        var key = field.substr(0, kv_split).strip_edges().to_lower()
        var value = field.substr(kv_split + 1).strip_edges()
        
        match key:
            "tag", "trigger_tags":
                # 支持方括号语法: [tag1,tag2] — 剥离括号再按逗号拆分
                if value.begins_with("[") and value.ends_with("]"):
                    value = value.substr(1, value.length() - 2)
                # 逗号分隔的多个 4 段式 tag
                var tags = value.split(",")
                for tag_str in tags:
                    var clean_tag = tag_str.strip_edges()
                    if not clean_tag.is_empty():
                        # 用现有的 MicroDSLParser 验证标签格式
                        var parsed = MicroDSLParser.parse_tags(clean_tag)
                        if not parsed.is_empty():
                            result.trigger_tags.append_array(parsed)
                        else:
                            # 即使是无效格式也直接存（保持宽容）
                            result.trigger_tags.append(clean_tag)
            
            "weight":
                var weight_val = value.to_float()
                if weight_val == 0.0 and value != "0" and value != "0.0":
                    print("Warning: Context weight 解析失败: %s" % value)
                else:
                    result.weight = weight_val
            
            "background":
                # 去掉括号包裹（兼容旧格式 (bg_name)）
                if value.begins_with("(") and value.ends_with(")"):
                    value = value.substr(1, value.length() - 2)
                result.background = value
            
            _:
                # 自定义模板参数
                result.custom_params[key] = value
    
    return result

# ---------- 事件/选项解析 ----------

# 解析 template URN，从已有资源 duplicate 并替换 uuid
# 返回 null 表示 template 不可用（空、解析失败、类型不匹配），由调用方兜底创建新对象
static func _resolve_template(template_urn: String, new_uuid: String) -> RandomEvent:
    if template_urn.is_empty():
        return null
    
    var template_resource = URN.get_resource_through_urn(template_urn)
    if template_resource == null:
        Logging.warn("Template URN 解析失败，资源不存在: %s" % template_urn)
        return null
    
    if not (template_resource is RandomEvent):
        Logging.warn("Template URN 返回的类型不是 RandomEvent (urn: %s, type: %s)" % [template_urn, typeof(template_resource)])
        return null
    
    var event = template_resource.duplicate() as RandomEvent
    if not new_uuid.is_empty():
        event.uuid = new_uuid
    
    Logging.info("Template 应用成功: %s -> uuid=%s" % [template_urn, event.uuid])
    return event

# 解析随机事件（row_type = 'random_event'）
static func parse_random_event(row: Dictionary) -> RandomEvent:
    # 检测空行
    if row.is_empty():
        return null

    var has_content = false
    for key in row:
        var value = row[key]
        if value != null and not str(value).is_empty():
            has_content = true
            break

    if not has_content:
        return null

    # 解析 uuid（必需）
    var uuid = row.get('uuid')
    if not uuid or uuid.is_empty():
        push_error("UUID is required")
        return null

    # 解析 template URN（可选），优先从已有资源 duplicate
    var template_urn = row.get('template', '')
    var event: RandomEvent = _resolve_template(template_urn, uuid)

    # Fallback: template 不可用时创建新对象
    if not event:
        event = RandomEvent.new({})
        event.uuid = uuid
    else:
        # 确保 uuid 被正确覆盖（_resolve_template 内部已处理，双重保障）
        event.uuid = uuid

    # 解析 context DSL
    var context_str = row.get('context', '')
    var context_data = parse_context(context_str)
    
    # 从 context 中提取触发标签
    event._target_tags = context_data.trigger_tags
    
    # 从 context 中提取权重
    event.weight = context_data.weight
    
    # TODO: 背景需要走 URN 解析系统，目前先用 TextureResLoader 兜底
    var bg = context_data.background
    if not bg.is_empty():
        event.icon = TextureResLoader.get_background(bg)

    # 从 context 中提取自定义参数，init 时 merge 进 context
    event.custom_context_params = context_data.custom_params

    # 解析触发条件
    var requirements_str = row.get('requirements')
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)

    # 解析表现层
    event.name = row.get('title', "")
    event.description = row.get('description', "")

    # 解析事件级别结果（即使不选选项也会执行）
    var results_str = row.get('results')
    if results_str and not results_str.is_empty():
        event.event_result = parse_choice_result(results_str)

    # 解析情绪配置（目前仅 event 级别支持，未来 option 可能也有自己的 emotion_config）
    var emotion_config_str = row.get('emotion_config', '')
    if emotion_config_str and not emotion_config_str.is_empty():
        event.emotion_configs = parse_emotion_configs(emotion_config_str)
        Logging.info("Event 级 emotion_config 解析成功: uuid=%s" % uuid)

    return event

# 解析选项子行（row_type = 'option'，深度+1 的子行）
# 选项行可以有自己的 context、requirements、results，
# 解析结果作为一个独立的 RandomEvent 返回，由调用方决定如何挂载到父事件
static func parse_option_row(row: Dictionary) -> RandomEvent:
    if row.is_empty():
        return null

    var has_content = false
    for key in row:
        var value = row[key]
        if value != null and not str(value).is_empty():
            has_content = true
            break

    if not has_content:
        return null

    # 选项行也可能有 uuid（用于引用）
    var uuid = row.get('uuid', '')

    # 解析 template URN（可选），优先从已有资源 duplicate
    var template_urn = row.get('template', '')
    var event: RandomEvent = _resolve_template(template_urn, uuid)

    # Fallback: template 不可用时创建新对象
    if not event:
        event = RandomEvent.new({})
        event.uuid = uuid

    # 选项的 context
    var context_str = row.get('context', '')
    var context_data = parse_context(context_str)
    event.custom_context_params = context_data.custom_params

    # 选项的触发条件（通常是选择条件）
    var requirements_str = row.get('requirements')
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)

    # 选项的标题/描述
    event.name = row.get('title', "")
    event.description = row.get('description', "")

    # 选项的结果（选择后执行）
    var results_str = row.get('results')
    if results_str and not results_str.is_empty():
        event.event_result = parse_choice_result(results_str)

    # 选项的 emotion_config：虽然未来 option 可能也有自己的 config
    # 但目前只有 event 有，option 忽略并 warn（如果写了的话）
    var emotion_config_str = row.get('emotion_config', '')
    if emotion_config_str and not emotion_config_str.is_empty():
        Logging.warn("Option 行暂不支持 emotion_config，已忽略: uuid=%s" % uuid)

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
        option.requirement = parse_option_requirement(requirement_str)
    
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

# 解析特性数据
static func parse_trait(row: Dictionary) -> Trait:
    if row.is_empty():
        return null

    var has_content = false
    for key in row:
        var value = row[key]
        if value != null and not str(value).is_empty():
            has_content = true
            break

    if not has_content:
        return null

    var trait_ = Trait.new()

    var trait_id = row.get('trait_id')
    if not trait_id or trait_id.is_empty():
        push_error("trait_id is required")
        return null
    trait_.uuid = trait_id

    trait_.name = row.get('trait_name', '')
    trait_.topic = row.get('topic', '')
    trait_.specific_topic = row.get('specific_topic', '')

    var relate_to_str = row.get('relate_to', '')
    if not relate_to_str.is_empty():
        var enum_index = ENUMS.RELATION_TARGET.keys().find(relate_to_str.to_upper())
        if enum_index >= 0:
            trait_._relate_to = enum_index
        else:
            print("Warning: Unknown relate_to '%s' for trait %s" % [relate_to_str, trait_id])

    var lasting_xun_str = row.get('lasting_xun', '')
    if not lasting_xun_str.is_empty():
        trait_.lasting_xun = lasting_xun_str.to_int()

    # 解析 trait_effect_operations — DSL 格式: prop:property:±value,prop:property:±value
    var effect_ops_str = row.get('trait_effect_operations', '')
    if not effect_ops_str.is_empty():
        var all_ops = MicroDSLParser.parse_consequence_operators(effect_ops_str)
        var property_ops: Array[PropertyOperator] = []
        for op in all_ops:
            if op is PropertyOperator:
                property_ops.append(op as PropertyOperator)
        trait_.trait_effect_operations = property_ops
        if property_ops.size() != all_ops.size():
            print("Warning: trait %s: %d non-PropertyOperator entries in trait_effect_operations were filtered out" % [trait_id, all_ops.size() - property_ops.size()])

    # 解析 trait_endogenous_operations — DSL 格式: type:action:value,type:action:value
    var endogenous_ops_str = row.get('trait_endogenous_operations', '')
    if not endogenous_ops_str.is_empty():
        trait_.trait_endogenous_operations = MicroDSLParser.parse_consequence_operators(endogenous_ops_str)

    print("Trait解析成功: %s (topic=%s)" % [trait_id, trait_.topic])
    return trait_

static func validate_trait(trait_: Trait) -> bool:
    if not trait_:
        return false

    if not trait_.uuid or trait_.uuid.is_empty():
        push_error("Trait validation failed: missing trait_id")
        return false

    return true

# ---------- 下推自动机：CSV行列解析 ----------

# 批量解析CSV数据
# random_event 类型使用下推自动机（Pushdown Automaton）解析层级结构
# flags / trait 等扁平数据使用传统逐行解析
static func parse_csv_data(csv_data: Array[Dictionary], data_type: String = "random_event") -> Array[Resource]:
    var resources: Array[Resource] = []
    
    # 使用 URN enum 对照判断数据类型
    var urn_type = URN.find_urn_type(data_type)
    if urn_type != URN.URN_TYPE.RANDOM_EVENT:
        return _parse_flat_data(csv_data, urn_type)
    
    # ── random_event: 下推自动机 ──
    var stack: Array[RandomEvent] = []  # 事件栈，维护当前解析层级
    
    for i in range(csv_data.size()):
        var row = csv_data[i]
        var depth = _get_row_depth(row)
        var row_type = str(row.get("row_type", "")).strip_edges()
        
        # 从 row_type 中提取前置 > 作为深度标记（如 >option → depth=1, type=option）
        # 用户可以在 row_type 列直接用 > 前缀表示层级，避免写缩进
        if row_type.length() > 0:
            var gt_count = 0
            while gt_count < row_type.length() and row_type[gt_count] == '>':
                gt_count += 1
            if gt_count > 0:
                depth = gt_count
                row_type = row_type.substr(gt_count).strip_edges()
        
        if row_type.is_empty():
            continue
        
        _pda_transition(stack, resources, depth, row_type, row, i)
    
    # 处理栈中剩余事件
    _pda_flush_stack(stack, resources)
    
    return resources

# 下推自动机状态转移函数
# 维护一个事件栈，栈深度对应 CSV 的 > 层级：
#   depth=0 → 顶层事件（random_event）
#   depth=1 → 选项子行（option，挂载到栈顶事件）
#   depth=N → 第N层嵌套
# 弹出栈顶时，若栈变空则说明该顶层事件已完成，加入 resources
static func _pda_transition(stack: Array[RandomEvent], resources: Array[Resource],
                            depth: int, row_type: String, row: Dictionary, row_index: int) -> void:
    # ── 第一步：根据深度调整栈 ──
    # 如果栈深度 > 当前行深度，弹出栈顶事件
    # 弹出后若栈为空，说明这是个顶层事件完成了
    while stack.size() > depth:
        var popped = stack.pop_back()
        if stack.is_empty() and validate_event(popped):
            resources.append(popped)
    
    # ── 第二步：根据 row_type 解析当前行并压栈/挂载 ──
    match row_type:
        "random_event":
            var event = parse_random_event(row)
            if event:
                stack.push_back(event)
        
        "option":
            if stack.is_empty():
                push_error("下推自动机错误：option 行没有父事件 (row %d) 💀" % (row_index + 1))
                return
            
            var opt_event = parse_option_row(row)
            if opt_event:
                var parent = stack.back()
                var opt = EventOption.new()
                opt.description = opt_event.name
                opt.requirement = opt_event.requirement
                opt.choice_result = opt_event.event_result
                parent.options.append(opt)
        
        _:
            Logging.warn("未知 row_type '%s' (row %d)" % [row_type, row_index + 1])

# 清空栈，将尚未弹出的顶层事件加入 resources
static func _pda_flush_stack(stack: Array[RandomEvent], resources: Array[Resource]) -> void:
    while not stack.is_empty():
        var event = stack.pop_back()
        if stack.is_empty() and validate_event(event):
            resources.append(event)

# 扁平数据解析（flags / trait），逐行独立解析
static func _parse_flat_data(csv_data: Array[Dictionary], data_type: int) -> Array[Resource]:
    var resources: Array[Resource] = []
    for i in range(csv_data.size()):
        var row = csv_data[i]
        var resource: Resource = null
        
        match data_type:
            URN.URN_TYPE.FLAG:
                var flag = parse_flag(row)
                if flag and validate_flag(flag):
                    resource = flag
                else:
                    print("Warning: Failed to parse flag at row %d" % (i + 1))
            URN.URN_TYPE.TRAIT:
                var trait_ = parse_trait(row)
                if trait_ and validate_trait(trait_):
                    resource = trait_
                else:
                    print("Warning: Failed to parse trait at row %d" % (i + 1))
            _:
                push_error("未知的 data_type enum: %d 💀" % data_type)
                continue
        
        if resource:
            resources.append(resource)
    
    return resources
