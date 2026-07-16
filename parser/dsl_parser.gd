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

# ──────────────────────────────────────────────
# CSV 数据 Linter 验证：检测 results 列中的 requirement-only 函数
# ──────────────────────────────────────────────
# 场景：用户在 Google Sheets 中把 requirement 函数（如 flag_int_lt）
# 错误地填在 results 列。此函数仅做验证报错，不自动修数据。
# 数据问题需要在 Google Sheets 源头手动修复。
#
# 已知的 requirement-only 函数名列表（来自 MicroDSLParser._requirement_dispatch）
const _REQUIREMENT_ONLY_FUNCS: Array[String] = [
    "prop_gt", "prop_lt",
    "emo_gt", "emo_lt",
    "trait_has", "trait_not_has",
    "flag_bool_has", "flag_bool_not_has",
    "flag_str_is", "flag_str_not",
    "flag_int_gt", "flag_int_lt", "flag_int_eq", "flag_int_ne",
    "poem_has",
    "imagery_add",
    "imaginary_level_reward",
]

# 必须使用全角标点的 ASCII 等价物集合（用于纯文本字段校验）
# 纯文本（title/description）中出现这些 ASCII 标点意味着 Google Sheets 里填错了格式
const _ASCII_PUNCTUATION_CHARS: Array[String] = [
    "(", ")",  # 应使用（）
    ",",       # 应使用，
    ":",       # 应使用：
    ";",       # 应使用；
    "!",       # 应使用！
    "?",       # 应使用？
]

# 禁止在 DSL 代码字段中出现的全角标点集合
# DSL 代码字段（requirements/results/context 等）只能使用 ASCII 标点
const _FULLWIDTH_PUNCTUATION_CHARS: Array[String] = [
    "\uff08", "\uff09",  # （） 应使用 ()
    "\uff0c",            # ， 应使用 ,
    "\uff1a",            # ： 应使用 :
    "\uff1b",            # ； 应使用 ;
    "\uff01",            # ！ 应使用 !
    "\uff1f",            # ？ 应使用 ?
    "\uff5c",            # ｜ 应使用 |
    "\uff0f",            # ／ 应使用 /
]

# Linter 验证：检测纯文本字段中的英文标点
# 纯文本字段（title/description）只能使用全角中文标点
# 如果出现英文标点，说明数据源（Google Sheets）填写错误
static func _lint_text_field(text: String, field_name: String, uuid: String) -> void:
    if text.is_empty():
        return
    
    for punct in _ASCII_PUNCTUATION_CHARS:
        var idx = text.find(punct)
        if idx != -1:
            var context_start = max(0, idx - 4)
            var context_end = min(text.length(), idx + 5)
            var context_snippet = text.substr(context_start, context_end - context_start)
            Logging.warn("[Linter] 事件 '%s' 的 '%s' 字段包含英文标点 '%s' (位置 %d, 附近: '...%s...')，请替换为全角标点 💀" % [uuid, field_name, punct, idx, context_snippet])

# Linter 验证：检测 DSL 代码字段中的全角标点
# DSL 代码字段（requirements/results/context/interruptions/provider/template）
# 只能使用 ASCII 标点。出现全角标点会破坏 DSL 解析器。
static func _lint_dsl_field(text: String, field_name: String, uuid: String) -> void:
    if text.is_empty():
        return
    
    for punct in _FULLWIDTH_PUNCTUATION_CHARS:
        var idx = text.find(punct)
        if idx != -1:
            var context_start = max(0, idx - 4)
            var context_end = min(text.length(), idx + 5)
            var context_snippet = text.substr(context_start, context_end - context_start)
            Logging.warn("[Linter] 事件 '%s' 的 '%s' 字段包含全角标点 '%s' (位置 %d, 附近: '...%s...')，请替换为 ASCII 标点 💀" % [uuid, field_name, punct, idx, context_snippet])

# Linter 验证：检测 results 列中是否有 requirement-only 函数并报错
# 🚨 不修改数据，只报错。数据问题需在 Google Sheets 源头修复。
static func _lint_results_column(results_str: String, uuid: String) -> void:
    if results_str.is_empty():
        return
    
    var expressions = NamedDSLParser.split_expressions(results_str)
    if expressions.is_empty():
        return
    
    for expr in expressions:
        var clean_expr = expr.strip_edges()
        if clean_expr.is_empty():
            continue
        var paren_idx = clean_expr.find("(")
        if paren_idx == -1:
            continue
        var func_name = clean_expr.substr(0, paren_idx).strip_edges()
        if _REQUIREMENT_ONLY_FUNCS.find(func_name) != -1:
            Logging.err("[Linter] 事件 '%s' 的 results 列包含了 requirement 函数 '%s'，请将其迁移到 requirements 列 💀" % [uuid, clean_expr])

# ── Archetype 加载 ────────────────────────────────────
# 🆕 优先从 Database.action_archetypes（由 resource_converters.csv 注入）查找。
#    如果不存在，fallback 到 event_archetypes.json（旧格式，过渡期兼容）。
# 返回 Dictionary 或空字典（如果文件/archetype 不存在）。
# 公开方法，供 RandomEvent.on_enter() 运行时动态加载 archetype DSL 定义。
static var _event_archetypes_cache: Dictionary = {}

static func load_event_archetype(archetype_id: String) -> Dictionary:
    if archetype_id.is_empty():
        return {}
    
    # ── 方式 1: 从 Database.action_archetypes 查找（新路径，由 resource_converters.csv 注入）──
    var db_arch = Database.action_archetypes.get(archetype_id)
    if db_arch != null:
        # 将 ActionArchetype 转为旧 JSON 兼容的 Dictionary 返回
        return {
            "name": db_arch.name,
            "action_uuid": db_arch.action_uuid,
            "state": db_arch.state,
            "universal_requirement": db_arch.universal_requirement,
            "universal_result": db_arch.universal_result,
            "era": db_arch.era,
            "failed_hints": db_arch.failed_hints,
        }
    
    # ── 方式 2: Fallback 到 event_archetypes.json（旧格式，过渡期兼容）──
    if _event_archetypes_cache.is_empty():
        var path := "res://tools/data/event_archetypes.json"
        if not FileAccess.file_exists(path):
            Logging.info("DSLParser: event_archetypes.json 不存在，跳过（可能需要先同步 resource_converters.csv）")
            return {}
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            Logging.err("DSLParser: 无法打开 event_archetypes.json: %s" % path)
            return {}
        var raw := file.get_as_text()
        file.close()
        var json := JSON.new()
        var err := json.parse(raw)
        if err != OK:
            Logging.err("DSLParser: event_archetypes.json JSON 解析失败: %s" % json.get_error_message())
            return {}
        var data = json.get_data()
        if data is Dictionary:
            for key in data:
                if not key.begins_with("_"):
                    _event_archetypes_cache[key] = data[key]
        Logging.info("DSLParser: 加载 event_archetypes.json（旧格式），共 %d 个 archetype" % _event_archetypes_cache.size())
    
    if _event_archetypes_cache.has(archetype_id):
        return _event_archetypes_cache[archetype_id]
    
    Logging.warn("DSLParser: archetype '%s' 未在 Database 或 event_archetypes.json 中找到" % archetype_id)
    return {}

# 解析 context DSL 字段
# 语法格式（用 | 分隔字段，分层符号避免歧义）：
#   trigger_tags=[tagA:sub:cat:attr/tagB:sub:cat:attr]|weight=15.5|background=bg_rural_poor|customKey=customValue
# 已知字段:
#   tag / trigger_tags -> 触发标签列表（支持 [tag1/tag2] 方括号语法，Layer 2 / 分隔）
#   weight             -> 权重（float）
#   background         -> 背景图 URN
#   其他 key:value     -> 自定义模板参数
#
# 分层符号（按嵌套层级）：
#   Layer 0: |（顶层字段分隔符）
#   Layer 1: ;（字段值内的 k=v 链分隔符）
#   Layer 2: /（数组/列表元素分隔符）
static func parse_context(context_str: String) -> Dictionary:
    var result = {
        "trigger_tags": [] as Array[String],  # 🚨 必须用类型化 Array，否则 Godot 4 拒绝赋值给 Array[String] 变量
        "weight": 10.0,
        "background": "",
        "store_to": "",  # 🆕 store_to 路由指令：指定 .tres 输出目录的 key
        "era": "",       # 🆕 era 字段：标记该事件所属的时代（如 "745_ambition"），空=全时代可用
        "archetype": "", # 🆕 archetype 字段：事件类型标识符（如 "baiye"），对应 tools/data/event_archetypes.json
        "custom_params": {}
    }
    
    if context_str.is_empty():
        return result
    
    # 用 | 作为字段分隔符（Layer 0）
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
            Logging.info("Warning: Context 字段缺少分隔符 (= 或 :): %s" % field)
            continue
        
        var key = field.substr(0, kv_split).strip_edges().to_lower()
        var value = field.substr(kv_split + 1).strip_edges()
        
        match key:
            "tag", "trigger_tags":
                # 支持方括号语法: [tag1/tag2] — 剥离括号再按 / 拆分（Layer 2）
                if value.begins_with("[") and value.ends_with("]"):
                    value = value.substr(1, value.length() - 2)
                # / 分隔的多个 4 段式 tag
                var tags = value.split("/")
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
                    Logging.info("Warning: Context weight 解析失败: %s" % value)
                else:
                    result.weight = weight_val
            
            "background":
                # 去掉括号包裹（兼容旧格式 (bg_name)）
                if value.begins_with("(") and value.ends_with(")"):
                    value = value.substr(1, value.length() - 2)
                result.background = value
            
            "store_to":
                # 🆕 store_to 路由指令：指定生成的 .tres 文件输出目录
                # value 是 key，后续在 save_resources_to_tres() 中查 STORE_TO_PATH_MAP
                # 如果 key 不在映射表中，直接作为 res:// 相对路径使用
                result.store_to = value
            
            "era":
                # 🆕 era 字段：标记该事件所属的时代
                # 空字符串（默认值）表示对所有时代可用
                # 非空时，只在 GameState.current_era 匹配时参与抽取
                result.era = value
            
            "archetype":
                # 🆕 archetype 字段：事件类型标识符（如 "baiye"）
                # 对应 tools/data/event_archetypes.json 中的 key
                # 空字符串（默认值）表示该事件无类型标签
                result.archetype = value
            
            _:
                # 自定义模板参数
                # 支持 ; 分隔多个 key:value 对（如: poem_taste=urn:poem_taste:libai_taste; taste_owner_relation_flag=flag_relation_with_libai）
                # 方案：先存第一个 key:value，再检测 value 中的 ; 并尝试拆分附加键值对
                
                # 🚨 方括号数组语法必须在 ; 处理逻辑之前检测
                # 语法：some_name=[val1;val2;val3] — Layer 1 ; 分隔数组元素
                if value.begins_with("[") and value.ends_with("]"):
                    var inner = value.substr(1, value.length() - 2)
                    if inner.contains(";"):
                        # 分号分隔的数组
                        var arr = PackedStringArray()
                        for part in inner.split(";"):
                            part = part.strip_edges()
                            if not part.is_empty():
                                arr.append(part)
                        result.custom_params[key] = arr
                    else:
                        # 无分号 → 单元素数组（保持类型一致）
                        var clean_val = inner.strip_edges()
                        result.custom_params[key] = PackedStringArray([clean_val]) if not clean_val.is_empty() else PackedStringArray()
                    continue  # 🚨 跳过后续 ; 处理逻辑
                
                result.custom_params[key] = value
                
                if value.contains(";"):
                    var sub_parts = value.split(";")
                    # 第一个子段作为当前 key 的精确值（去掉 strip）
                    result.custom_params[key] = sub_parts[0].strip_edges()
                    # 剩余子段尝试解析为额外的 key:value
                    for i in range(1, sub_parts.size()):
                        var part = sub_parts[i].strip_edges()
                        if part.is_empty():
                            continue
                        # 兼容 = 和 : 两种 kv 分隔符（主解析器也用同样的逻辑）
                        var kv_div = -1
                        var eq_pos = part.find("=")
                        var colon_pos = part.find(":")
                        if eq_pos != -1:
                            kv_div = eq_pos
                        elif colon_pos != -1:
                            kv_div = colon_pos
                        
                        if kv_div != -1:
                            var ek = part.substr(0, kv_div).strip_edges()
                            var ev = part.substr(kv_div + 1).strip_edges()
                            result.custom_params[ek] = ev
                        else:
                            # 没有分隔符，拼回去
                            result.custom_params[key] += ";" + part
    
    return result

# ---------- 事件/选项解析 ----------

# 工厂函数：根据行类型解析并校验 template URN
# 在行解析的最开始时调用，提前发现类型不匹配问题
# 校验通过后直接 duplicate 返回实例
#   "random_event" → 校验 is RandomEvent，返回 RandomEvent
#   "option"       → 校验 is RandomEvent / is EventOption，返回对应类型
static func _resolve_template_for_type(template_urn: String, row_type: String, new_uuid: String):
    if template_urn.is_empty():
        return null
    
    var template_resource = URN.get_resource_through_urn(template_urn)
    if template_resource == null:
        Logging.warn("Template URN 解析失败，资源不存在 (urn: %s, row_type: %s)" % [template_urn, row_type])
        return null
    
    # 校验类型
    var type_ok = false
    match row_type:
        "random_event":
            type_ok = template_resource is RandomEvent
        "option":
            type_ok = template_resource is RandomEvent or template_resource is EventOption
        _:
            Logging.warn("未知的行类型 '%s'，跳过 template 类型检查 (urn: %s)" % [row_type, template_urn])
            return null
    
    if not type_ok:
        Logging.warn("Template 类型不匹配: %s 行不兼容 URN '%s' 返回的 %s (type: %d)" % [
            row_type, template_urn, template_resource.get_class(), typeof(template_resource)])
        return null
    
    # 校验通过，直接 duplicate 返回
    var instance = template_resource.duplicate()
    if instance is RandomEvent and not new_uuid.is_empty():
        instance.uuid = new_uuid
    Logging.info("Template 应用成功 (%s): %s" % [row_type, template_urn])
    return instance

# ═══════════════════════════════════════════════════════════
# Provider 解析
#
# CSV provider 列语法（类似 operator）：
#   item_provider(list_key="guests", text_template="走向 {item}", ...)
#
# 规则：
#   1. 使用 NamedDSLParser.parse_single() 解析（和 operator 一样）
#   2. 函数名映射到 Provider 类（目前仅 item_provider → ItemProvider）
#   3. 参数 key=value 直接 set 到 provider 实例的对应 @export 字段
#   4. 不支持多个 provider，只取一个
# ═══════════════════════════════════════════════════════════

# 函数名 → Provider 脚本路径映射
# 🚨 不用 class_name 直接引用，避免 @tool 模式下跨脚本解析异常 💀
# 改用 load() 延迟加载，新增 provider 类型时在此注册
static func _load_provider_script(func_name: String) -> GDScript:
    match func_name:
        "item_provider":
            return load("res://core/model/item_provider.gd")
        _:
            return null

static func _create_provider_instance(func_name: String, params: Dictionary) -> BaseProvider:
    var script: GDScript = _load_provider_script(func_name)
    if script == null:
        Logging.err("Provider 解析失败: 未知的 provider 函数 '%s'" % func_name)
        return null
    
    var provider = script.new() as BaseProvider
    if provider == null:
        Logging.err("Provider 实例化失败: func_name=%s, script=%s" % [func_name, script.resource_path])
        return null
    
    # 将 params 中的 key=value 映射到 provider 的属性
    for key in params:
        if key in provider:
            var value = params[key]
            provider.set(key, value)
            Logging.info("Provider 属性设置: %s.%s = %s (type: %s)" % [func_name, key, str(value), typeof(value)])
        else:
            Logging.warn("Provider '%s' 没有属性 '%s'，已忽略" % [func_name, key])
    
    Logging.info("Provider 创建成功: %s (params: %s)" % [func_name, str(params)])
    return provider

# 解析 provider 字段
# 输入: "item_provider(list_key="guests", text_template="走向 {item}", target_event_key="event_talk", payload_key="target_npc")"
# 返回: BaseProvider 实例，或 null（空字符串 / 解析失败）
static func parse_provider_field(provider_str: String) -> BaseProvider:
    if provider_str.is_empty():
        return null
    
    var parsed = NamedDSLParser.parse_single(provider_str)
    if parsed == null:
        Logging.err("Provider DSL 解析失败: %s" % provider_str)
        return null
    
    var provider = _create_provider_instance(parsed.func_name, parsed.params)
    if provider == null:
        Logging.err("Provider 实例创建失败: func_name=%s, str=%s" % [parsed.func_name, provider_str])
        return null
    
    return provider

# ═══════════════════════════════════════════════════════════
# Interruption 解析（interruptions 列）
#
# CSV interruptions 列语法（支持多个，| 分隔）：
#   interrupt_event(requirement_syntax| operator_syntax)
#
# 示例：
#   interrupt_event(prop_gt(name=money; val=50)| push_event(event_key=event_poverty))
#   interrupt_event(flag_bool_has(name=has_sword)| push_event(event_key=event_duel))
#
# requirement_syntax 使用 parse_requirements() 解析（复用现有需求语法）
# operator_syntax    使用 MicroDSLParser.parse_consequence_operators() 解析
# ═══════════════════════════════════════════════════════════

# 解析单个 interrupt_event(...) 调用，返回 ConditionalOperator 实例
static func parse_interruption_field(interruption_str: String) -> ConditionalOperator:
    interruption_str = interruption_str.strip_edges()
    if interruption_str.is_empty():
        Logging.warn("parse_interruption_field: 空字符串")
        return null
    
    # 提取函数名和参数内容
    var paren_open = interruption_str.find("(")
    var paren_close = interruption_str.rfind(")")
    if paren_open == -1 or paren_close == -1 or paren_close <= paren_open:
        Logging.err("parse_interruption_field: 缺少括号，格式应为 interrupt_event(req| op): %s" % interruption_str)
        return null
    
    var func_name = interruption_str.substr(0, paren_open).strip_edges()
    if func_name != "interrupt_event":
        Logging.err("parse_interruption_field: 未知函数 '%s'，期望 'interrupt_event': %s" % [func_name, interruption_str])
        return null
    
    var args_str = interruption_str.substr(paren_open + 1, paren_close - paren_open - 1)
    if args_str.is_empty():
        Logging.err("parse_interruption_field: 缺少参数: %s" % interruption_str)
        return null
    
    # 用 split_expressions 分割两个位置参数（按顶级 | 分割，Layer 0）
    var args = NamedDSLParser.split_expressions(args_str)
    if args.size() < 2:
        Logging.err("parse_interruption_field: 需要 2 个参数（requirement, operator），实际 %d: %s" % [args.size(), interruption_str])
        return null
    
    var requirement_syntax = args[0].strip_edges()
    # 合并剩余参数作为 operators（args[1..] 都是 operator，可能存在多个）
    var operator_syntax = ""
    for i in range(1, args.size()):
        if i > 1:
            operator_syntax += "|"
        operator_syntax += args[i].strip_edges()
    
    # 解析 requirement
    # 支持 " and " 语法（带空格，避免误匹配含 and 的关键词）
    # 示例: interrupt_event(cond1 and cond2| op)
    #       → 分割为 cond1, cond2，合并为 ComplexRequirements（AND 逻辑）
    # 如果无 " and "，回退到现有逗号分隔的 AND 语法
    var requirement: BaseRequirements = null
    if not requirement_syntax.is_empty():
        var and_parts = requirement_syntax.split(" and ")
        if and_parts.size() > 1:
            # " and " 语法：分别解析每个条件，合并为 ComplexRequirements
            var parsed_reqs: Array[BaseRequirements] = []
            for part in and_parts:
                var clean_part = part.strip_edges()
                if clean_part.is_empty():
                    continue
                var single_req = parse_single_requirement(clean_part)
                if single_req:
                    parsed_reqs.append(single_req)
                else:
                    Logging.warn("parse_interruption_field: ' and ' 条件解析失败: '%s'" % clean_part)
            
            if parsed_reqs.size() > 1:
                var complex_req = ComplexRequirements.new()
                complex_req.operators = parsed_reqs
                complex_req.current_operator = REQ_OPERATOR.LOGIC.AND
                requirement = complex_req
            elif parsed_reqs.size() == 1:
                requirement = parsed_reqs[0]
            # parsed_reqs 为空 → requirement 保持 null
        else:
            # 无 " and " 语法，回退到原有 | 分隔语法（Layer 0）
            requirement = parse_requirements(requirement_syntax)
            if requirement == null:
                Logging.warn("parse_interruption_field: requirement 解析失败: '%s'" % requirement_syntax)
    
    # 解析 operators（支持多个 operator，| 分隔，Layer 0）
    var operators: Array[BaseOperator] = []
    if not operator_syntax.is_empty():
        operators = MicroDSLParser.parse_consequence_operators(operator_syntax)
        if operators.is_empty():
            Logging.warn("parse_interruption_field: operator 解析失败: '%s'" % operator_syntax)
    
    # 创建 ConditionalOperator
    var cond_op = ConditionalOperator.new()
    cond_op.condition = requirement
    cond_op.condition_success_result = operators
    # condition_fail_result 留空 — 中断场景中条件不通过就是跳过，无需额外操作
    
    Logging.info("parse_interruption_field: 解析成功 (requirement=%s, operators=%d)" % [requirement_syntax, operators.size()])
    return cond_op


# 解析 interruptions 列（支持多个 interrupt_event() 调用，| 分隔，Layer 0）
# ⚡ 返回非类型化 Array，因为 BaseEvent.pre_event_interrupter_sequence 声明为 @export var ...: Array = []
# 使用类型化返回值 Array[ConditionalOperator] 在 @tool 模式下赋值给 @export Array 属性会导致
# "Invalid assignment of property or key" 错误，进而导致整个 parse_random_event 函数中断 💀
static func parse_interruptions_field(interruptions_str: String) -> Array:
    var results: Array = []
    
    if interruptions_str.is_empty():
        return results
    
    var expressions = NamedDSLParser.split_expressions(interruptions_str)
    for expr in expressions:
        var clean_expr = expr.strip_edges()
        if clean_expr.is_empty():
            continue
        
        var cond_op = parse_interruption_field(clean_expr)
        if cond_op:
            results.append(cond_op)
        else:
            Logging.warn("parse_interruptions_field: 子项解析失败，已跳过: '%s'" % clean_expr)
    
    Logging.info("parse_interruptions_field: 解析完成，共 %d 个 interrupt 步骤" % results.size())
    return results


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
        Logging.err("UUID is required")
        return null

    # 解析 template URN（可选），优先从已有资源 duplicate
    # ⚡ 在行解析的最开始检查 template 类型，避免后续数据覆盖
    var template_urn = row.get('template', '')
    var template_result = _resolve_template_for_type(template_urn, "random_event", uuid)

    var event: RandomEvent
    if template_result is RandomEvent:
        event = template_result as RandomEvent
        # 确保 uuid 被正确覆盖（工厂函数内部已处理，双重保障）
        event.uuid = uuid
    else:
        event = RandomEvent.new({})
        event.uuid = uuid

    # 解析 provider 字段（新列，独立于 template）
    # 语法: item_provider(list_key="guests", text_template="走向 {item}", ...)
    # 使用 NamedDSLParser 解析（和 operator 一样的语法）
    var provider_str = row.get('provider', '')
    if not provider_str.is_empty():
        var provider = parse_provider_field(provider_str)
        if provider:
            event.provider = provider
            Logging.info("Provider 绑定成功: uuid=%s, provider=%s" % [uuid, provider_str])
        else:
            Logging.warn("Provider 解析失败，已跳过: uuid=%s, provider=%s" % [uuid, provider_str])

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

    # 🆕 store_to 路由指令：通过 custom_context_params 传递到保存阶段
    # 在 save_resources_to_tres() 中根据此值路由到对应目录
    if not context_data.store_to.is_empty():
        event.custom_context_params["store_to"] = context_data.store_to

    # 🆕 era 字段：从 context DSL 提取，标记事件所属时代
    event.era = context_data.era

    # 🆕 Archetype 标签：.tres 只持久化 archetype_id 字符串。
    # universal_requirement/result/era 在运行时由 RandomEvent.on_enter() 动态加载。
    var archetype_id = context_data.get("archetype", "")
    if not archetype_id.is_empty():
        event.archetype_id = archetype_id
        Logging.info("DSLParser: archetype '%s' tagged to event uuid=%s" % [archetype_id, uuid])

    # 解析触发条件
    var requirements_str = row.get('requirements')
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)

    # 解析表现层
    event.name = row.get('title', "")
    event.description = row.get('description', "")
    
    # 🚨 纯文本标点校验：title/description 中不应出现英文标点
    _lint_text_field(event.name, "title", uuid)
    _lint_text_field(event.description, "description", uuid)
    
    # 🚨 DSL 代码字段标点校验：不应出现全角标点
    var _dsl_context_str = row.get('context', '')
    _lint_dsl_field(_dsl_context_str, "context", uuid)
    var _dsl_req_str = row.get('requirements', '')
    _lint_dsl_field(_dsl_req_str, "requirements", uuid)
    var _dsl_provider_str = row.get('provider', '')
    _lint_dsl_field(_dsl_provider_str, "provider", uuid)
    var _dsl_template_str = row.get('template', '')
    _lint_dsl_field(_dsl_template_str, "template", uuid)

    # 🚨 旧版 results 列检测：如果在 event row 上发现 results 列，报错
    var legacy_results_str = row.get('results')
    if legacy_results_str and not legacy_results_str.is_empty():
        Logging.err("Event '%s' (uuid=%s): 'results' column is no longer supported for event rows. Use 'on_enter' column instead. See DOCUMENTATIONS/events/operator_variable_lifecycle.md §9.3" % [event.name, uuid])

    # 解析 on_enter 结果（舞台置景，即使不选选项也会执行）
    # 对应三层铁幕契约第一层：Event on_enter
    # 参见 DOCUMENTATIONS/events/operator_variable_lifecycle.md §9.3
    var on_enter_str = row.get('on_enter')
    if on_enter_str and not on_enter_str.is_empty():
        _lint_dsl_field(on_enter_str, "on_enter", uuid)
        event.on_enter_result = parse_choice_result(on_enter_str)

    # 解析 on_returned 回归叙事文本（纯字符串，非 DSL）
    # 当子事件 pop_event 回到此事件时，与 transition_text 合并打印为 NarrativeText 条目
    var on_returned_str = row.get('on_returned', '')
    if on_returned_str and not on_returned_str.is_empty():
        event.on_returned = on_returned_str
        Logging.info("Event on_returned 解析成功: uuid=%s" % uuid)

    # 解析前置中断序列（interruptions 列）
    # 语法: interrupt_event(req_syntax| op_syntax)|interrupt_event(req_syntax2| op_syntax2)
    var interruptions_str = row.get('interruptions', '')
    if not interruptions_str.is_empty():
        _lint_dsl_field(interruptions_str, "interruptions", uuid)
    if interruptions_str and not interruptions_str.is_empty():
        var interruptions = parse_interruptions_field(interruptions_str)
        if not interruptions.is_empty():
            # 🚨 @tool 模式下，直接 `event.pre_event_interrupter_sequence = interruptions`
            # 可能触发 Godot 引擎 ERR_FAIL（类继承链未完全加载时属性不可达），
            # 导致整个 parse_random_event 被 abort 并返回 null 💀
            #
            # 改用 event.set() 绕过：
            #   set() 内部虽然也用 ERR_FAIL，但 GDScript 绑定将其视为 void 返回，
            #   不会 abort 调用方函数。即使 set() 内部 push_error，代码仍能继续执行。
            event.set(&"pre_event_interrupter_sequence", interruptions)
            Logging.info("Event interruptions 解析成功: uuid=%s, count=%d" % [uuid, interruptions.size()])

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
    # ⚡ 在行解析的最开始检查 template 类型，避免后续数据覆盖
    var template_urn = row.get('template', '')
    var template_result = _resolve_template_for_type(template_urn, "option", uuid)

    var event: RandomEvent
    if template_result is RandomEvent:
        # RandomEvent template → 直接使用
        event = template_result as RandomEvent
        event.uuid = uuid
    elif template_result is EventOption:
        # EventOption template → 转换为 RandomEvent
        event = RandomEvent.new({})
        event.uuid = uuid
        event.name = template_result.description
        event.description = template_result.description
        event.requirement = template_result.requirement
        event.on_enter_result = template_result.choice_result
    else:
        # 无 template / 类型不匹配 → 创建新对象
        event = RandomEvent.new({})
        event.uuid = uuid

    # 选项的 context
    var context_str = row.get('context', '')
    _lint_dsl_field(context_str, "context", uuid)
    var context_data = parse_context(context_str)
    event.custom_context_params = context_data.custom_params

    # 🚨 option 行禁止使用 store_to（这是个路由指令，只有 event 能指定）
    if not context_data.store_to.is_empty():
        Logging.err("parse_option_row: option 行不能指定 store_to！uuid=%s, value=%s" % [uuid, context_data.store_to])

    # 选项的触发条件（通常是选择条件）
    var requirements_str = row.get('requirements')
    _lint_dsl_field(requirements_str if requirements_str != null else "", "requirements", uuid)
    if requirements_str and not requirements_str.is_empty():
        event.requirement = parse_requirements(requirements_str)

    # 选项的标题/描述
    event.name = row.get('title', "")
    event.description = row.get('description', "")
    
    # 🚨 纯文本标点校验：title/description 中不应出现英文标点
    _lint_text_field(event.name, "title", uuid)
    _lint_text_field(event.description, "description", uuid)

    # 选项的结果（选择后执行）
    # 注意：选项行的 results 列设置的是 choice_result（通过 on_enter_result 传递），
    # 不同于事件行的 on_enter 列。
    # 🚨 合并策略：当 template 已有 on_enter_result（如 MenuStartOperator）时，
    #   将 CSV results 的 operators 追加到其后，而非直接覆盖。
    #   参见 DOCUMENTATIONS/old_bugs.md §2026-05-28: EventOption template 的 operators 通过 PDA 链路丢失
    var results_str = row.get('results')
    _lint_dsl_field(results_str if results_str != null else "", "results", uuid)
    if results_str and not results_str.is_empty():
        _lint_results_column(results_str, uuid)
        var csv_result = parse_choice_result(results_str)
        var csv_op_count = csv_result.operators.size()
        
        # 合并：template operators 在前，CSV results operators 在后
        if event.on_enter_result and not event.on_enter_result.operators.is_empty():
            var merged_ops = event.on_enter_result.operators.duplicate()
            merged_ops.append_array(csv_result.operators)
            csv_result.operators = merged_ops
            Logging.info("parse_option_row: 合并 template operators (%d) + CSV results operators (%d) 用于 option '%s'" % [
                event.on_enter_result.operators.size(),
                csv_op_count,
                uuid])
        
        event.on_enter_result = csv_result

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
        Logging.err("parse_flag: flag_id is required")
        return null
    flag.uuid = flag_id

    # 解析 type 字段
    var flag_type = row.get('type', 'str')
    if flag_type not in ['str', 'int', 'bool']:
        Logging.info("Warning: Invalid flag type '%s' for flag %s, defaulting to 'str'" % [flag_type, flag_id])
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
            Logging.info("Warning: Unknown flag type '%s', defaulting to str" % flag_type)
            flag.val_str = str(default_value)

    Logging.info("Flag解析成功: %s (type=%s, default=%s)" % [flag_id, flag_type, default_value])
    return flag

# 主要的CSV解析方法（保持向后兼容）
static func parse(row: Dictionary) -> RandomEvent:
    return parse_random_event(row)

static func parse_background(bg: String) -> Texture2D:
    if bg.is_empty():
        return null
    return TextureResLoader.get_background(bg)

# 解析触发条件，支持多个条件的AND组合
# 使用 NamedDSLParser.split_expressions() 处理顶级 | 分割（Layer 0），
# 防止括号内的参数 ; 被误分割（如 prop_gt(name=money; val=50)）
static func parse_requirements(requirements_str: String) -> BaseRequirements:
    var parsed_requirements: Array[BaseRequirements] = []
    
    # 统一使用 split_expressions 处理 | 分割（Layer 0），兼容有括号和无括号的新语法表达式
    var expressions = NamedDSLParser.split_expressions(requirements_str)
    
    for clean_req in expressions:
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
# 委托给 MicroDSLParser.parse_requirement() 统一入口，
# 通过中央调度字典匹配 func_name，不再用 begins_with() 前缀匹配。
static func parse_single_requirement(req_str: String) -> BaseRequirements:
    var req = MicroDSLParser.parse_requirement(req_str)
    if req == null:
        Logging.info("Warning: Unknown requirement type: %s" % req_str)
    return req

# 解析选项（1, 2, 3等）
static func parse_options(row: Dictionary) -> Array[BaseOption]:
    var options: Array[BaseOption] = []

    # 支持多个选项：1/2/3/4等
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
    
    return option

# 解析选项门槛
# 委托给 MicroDSLParser.parse_requirement() 统一入口
static func parse_option_requirement(req_str: String) -> BaseRequirements:
    var req = MicroDSLParser.parse_requirement(req_str)
    if req == null:
        Logging.info("Warning: Unknown option requirement type: %s" % req_str)
    return req

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
        Logging.info("Warning: Event validation warning: no options for event %s" % event.uuid)

    if event.icon == null:
        Logging.info("Warning: Event validation warning: no icon for event %s" % event.uuid)

    return true

# 验证 Flag 解析结果
static func validate_flag(flag: Flag) -> bool:
    if not flag:
        return false

    if not flag.uuid or flag.uuid.is_empty():
        Logging.err("Flag validation failed: missing ID")
        return false

    if flag.type.is_empty():
        Logging.info("Warning: Flag validation warning: no type for flag %s" % flag.uuid)
        return false

    if flag.type not in ['str', 'int', 'bool']:
        Logging.info("Warning: Flag validation warning: invalid type '%s' for flag %s" % [flag.type, flag.uuid])
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
        Logging.err("parse_trait: trait_id is required")
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
            Logging.info("Warning: Unknown relate_to '%s' for trait %s" % [relate_to_str, trait_id])

    var lasting_xun_str = row.get('lasting_xun', '')
    if not lasting_xun_str.is_empty():
        trait_.lasting_xun = lasting_xun_str.to_int()

    # 解析 trait_effect_operations — DSL 格式: prop_add(name=money; val=±value)|prop_sub(name=reputation; val=±value)
    var effect_ops_str = row.get('trait_effect_operations', '')
    if not effect_ops_str.is_empty():
        var all_ops = MicroDSLParser.parse_consequence_operators(effect_ops_str)
        var property_ops: Array[PropertyOperator] = []
        for op in all_ops:
            if op is PropertyOperator:
                property_ops.append(op as PropertyOperator)
        trait_.trait_effect_operations = property_ops
        if property_ops.size() != all_ops.size():
            Logging.info("Warning: trait %s: %d non-PropertyOperator entries in trait_effect_operations were filtered out" % [trait_id, all_ops.size() - property_ops.size()])

    # 解析 display_char（印章展示字）
    var display_char_str = row.get('display_char', '')
    if not display_char_str.is_empty():
        trait_.display_char = display_char_str

    # 解析 time_penalty（每次行动额外消耗天数）
    var time_penalty_str = row.get('time_penalty', '')
    if not time_penalty_str.is_empty():
        trait_.time_penalty = time_penalty_str.to_int()

    # ─── 🆕 数据驱动字段解析 ───────────────────────────────

    # duration_xun（到期旬数，0=永久）
    var duration_str = row.get('duration_xun', '')
    if not duration_str.is_empty():
        trait_.duration_xun = duration_str.to_int()

    # expiry_trait（到期后替换的 trait UUID）
    var expiry_str = row.get('expiry_trait', '')
    if not expiry_str.is_empty():
        trait_.expiry_trait = expiry_str

    # conditional_time_penalty（条件化时间惩罚 DSL）
    # 格式: action_tag_match/penalty_days/description/add_to_all
    # 多个用 | 分隔，add_to_all 为 "true" 表示所有行动
    var ctp_str = row.get('conditional_time_penalty', '')
    if not ctp_str.is_empty():
        var entries = ctp_str.split('|', false)
        for entry in entries:
            var parts = entry.split('/', false)
            if parts.size() < 2:
                Logging.warn("parse_trait: conditional_time_penalty 格式错误: %s" % entry)
                continue
            var ctp = ConditionalTimePenalty.new()
            ctp.action_tag_match = parts[0].strip_edges()
            ctp.penalty_days = parts[1].strip_edges().to_int()
            if parts.size() >= 3:
                ctp.description = parts[2].strip_edges()
            if parts.size() >= 4:
                ctp.add_to_all = parts[3].strip_edges().to_lower() == "true"
            trait_.conditional_time_penalties.append(ctp)
            Logging.info("parse_trait: %s conditional_time_penalty: tag=%s days=%d desc=%s add_to_all=%s" % [trait_id, ctp.action_tag_match, ctp.penalty_days, ctp.description, str(ctp.add_to_all)])

    # narrative_murmur（潜意识碎碎念）
    var murmur_str = row.get('narrative_murmur', '')
    if not murmur_str.is_empty():
        trait_.narrative_murmur = murmur_str

    # ap_penalty（永久 AP 上限削减）
    var ap_penalty_str = row.get('ap_penalty', '')
    if not ap_penalty_str.is_empty():
        trait_.ap_penalty = ap_penalty_str.to_int()

    Logging.info("Trait解析成功: %s (topic=%s, time_penalty=%d, duration_xun=%d, ap_penalty=%d)" % [trait_id, trait_.topic, trait_.time_penalty, trait_.duration_xun, trait_.ap_penalty])
    return trait_

static func validate_trait(trait_: Trait) -> bool:
    if not trait_:
        return false

    if not trait_.uuid or trait_.uuid.is_empty():
        Logging.err("Trait validation failed: missing trait_id")
        return false

    return true

# ---------- StateTransistor 解析 ----------

# 解析状态转移器数据
# 表头直接照抄 StateTransistor 的属性名：
#   uuid, target_resource_urn, transist_value, current_resource_urn,
#   triggered_event_key, requirement, operators
# requirement 和 operators 两列走 DSL 解析，其余字段直接赋值
static func parse_state_transistor(row: Dictionary) -> StateTransistor:
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

    var transistor = StateTransistor.new()

    # ── 直接照抄的字段 ──
    transistor.uuid = row.get('uuid', '')
    # 🚨 CSV 列名是 target_resource / current_resource / triggered_event，没有 _urn 和 _key 后缀
    transistor.target_resource_urn = row.get('target_resource', '')
    transistor.transist_value = row.get('transist_value', '')
    transistor.current_resource_urn = row.get('current_resource', '')
    transistor.triggered_event_key = row.get('triggered_event', '')

    # ── DSL 解析字段 ──
    # requirement: 使用 parse_requirements() 解析 (复用 random_event 的解析逻辑)
    var requirements_str = row.get('requirement', '')
    if not requirements_str.is_empty():
        transistor.requirements = parse_requirements(requirements_str)

    # operators: 使用 MicroDSLParser.parse_consequence_operators() 解析
    # (复用 choice_result / trait_effect_operations 的解析逻辑)
    var operators_str = row.get('operators', '')
    if not operators_str.is_empty():
        transistor.operators = MicroDSLParser.parse_consequence_operators(operators_str)

    Logging.info("StateTransistor 解析成功: uuid=%s, target=%s" % [transistor.uuid, transistor.target_resource_urn])
    return transistor


static func validate_state_transistor(transistor: StateTransistor) -> bool:
    if not transistor:
        return false

    # target_resource_urn 可以为空（纯事件触发 / 纯 operators 模式），
    # 但必须至少有一个有意义的字段
    if transistor.target_resource_urn.is_empty() and transistor.triggered_event_key.is_empty() and transistor.operators.is_empty():
        Logging.err("StateTransistor validation failed: at least one of target_resource_urn, triggered_event_key, or operators must be set")
        return false

    return true

# ---------- 下推自动机：CSV行列解析 ----------

# 批量解析CSV数据
# random_event 类型使用下推自动机（Pushdown Automaton）解析层级结构
# flags / trait / resource_converter 等扁平数据使用传统逐行解析
static func parse_csv_data(csv_data: Array[Dictionary], data_type: String = "random_event") -> Array[Resource]:
    var resources: Array[Resource] = []
    
    # 🚨 避开 @tool 模式下 enum 跨脚本 match 解析异常的问题。
    # `URN.URN_TYPE.FLAG` 等枚举常量在 match 语句中可能无法正确解析为整数值，
    # 导致所有 data_type 都落入 _ 兜底分支。
    # 直接用原始字符串 match，简单粗暴有效 🤓☝️
    match data_type:
        "random_event":
            # ── 进入下推自动机逻辑 ──
            pass
        "trait", "flag", "state_transistor":
            return _parse_flat_data(csv_data, data_type)
        "resource_converter":
            return _parse_resource_converter(csv_data)
        _:
            Logging.err("parse_csv_data: 未知的 data_type 字符串: '%s' 💀" % data_type)
            return []
    
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
# 根据当前的深度和row_type共同判断如何解析: 我应该把这个抽象为一个类，让每个类自己负责对于其他类的状态转移，就像是工具模式
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
            else:
                Logging.warn("random_event 解析失败 (row %d)，该行被跳过，后续 option 将找不到父事件 💀" % (row_index + 1))
        
        "option":
            if stack.is_empty():
                Logging.err("下推自动机错误：option 行没有父事件 (row %d) 💀" % (row_index + 1))
                return
            
            # 🚨 优先检测是否有 EventOption template
            # ❌ 不直接 duplicate() template，因为 resource_local_to_scene = true 的
            #    EventOption 在 duplicate 后非 @export 的 var 属性变为只读，赋值会崩溃 💀
            # ✅ 改为手动创建新 EventOption，只拷贝需要的 @export 字段
            var template_urn = row.get('template', '')
            var template_source: EventOption = null
            if not template_urn.is_empty():
                var template_resource = URN.get_resource_through_urn(template_urn)
                if template_resource is EventOption:
                    template_source = template_resource as EventOption
                    Logging.info("Template 应用成功 (option, direct): %s" % template_urn)
                    
            
            if template_source:
                # ── 手动创建新 EventOption，从 template 拷贝字段 ──
                var parent = stack.back()
                var opt = EventOption.new()
                
                # 拷贝 @export 字段
                var uuid = row.get('uuid', '')
                opt.uuid = uuid if not uuid.is_empty() else template_source.uuid
                opt.description = template_source.description
                opt.requirement = template_source.requirement
                
                # 🚨 关键：拷贝 choice_result（含 operators）
                # 不能直接引用，必须深拷贝，否则会对同一个 template 实例产生副作用
                if template_source.choice_result:
                    opt.choice_result = template_source.choice_result.duplicate()
                
                # 解析 context 自定义参数
                var context_str = row.get('context', '')
                if not context_str.is_empty():
                    var context_data = parse_context(context_str)
                    if not context_data.custom_params.is_empty():
                        opt.custom_context_params = context_data.custom_params
                
                # 如果 CSV 行有显式的 title/description，覆盖 template 的
                var title = row.get('title', '')
                var description = row.get('description', '')
                if not title.is_empty():
                    opt.description = title
                if not description.is_empty():
                    opt.description = description
                
                # 如果 CSV 行有显式的 requirements，覆盖 template 的
                var requirements_str = row.get('requirements', '')
                if not requirements_str.is_empty():
                    opt.requirement = parse_requirements(requirements_str)
                
                # 如果 CSV 行有显式的 results，合并到 template 的 choice_result 之后
                # 🚨 合并而非覆盖：template 的 operators（如 MenuStartOperator）在前，
                #    CSV results 的 operators（如 PopEventOperator）在后。
                #    参见 DOCUMENTATIONS/old_bugs.md §2026-05-28
                var results_str = row.get('results', '')
                if not results_str.is_empty():
                    var csv_result = parse_choice_result(results_str)
                    if opt.choice_result and not opt.choice_result.operators.is_empty():
                        var merged_ops = opt.choice_result.operators.duplicate()
                        merged_ops.append_array(csv_result.operators)
                        csv_result.operators = merged_ops
                        Logging.info("_pda_transition: 合并 template operators (%d) + CSV results operators (%d) 用于 option '%s'" % [
                            opt.choice_result.operators.size(),
                            csv_result.operators.size() - opt.choice_result.operators.size(),
                            opt.uuid])
                    opt.choice_result = csv_result
                
                parent.options.append(opt)
            else:
                # ── 走原有的 RandomEvent 包装路径（无 template 或 template 是 RandomEvent） ──
                var opt_event = parse_option_row(row)
                if opt_event:
                    var parent = stack.back()
                    var opt = EventOption.new()
                    opt.description = opt_event.description
                    opt.requirement = opt_event.requirement
                    opt.choice_result = opt_event.on_enter_result
                    opt.custom_context_params = opt_event.custom_context_params.duplicate()
                    
                    parent.options.append(opt)
        
        _:
            Logging.warn("未知 row_type '%s' (row %d)" % [row_type, row_index + 1])

# 清空栈，将尚未弹出的顶层事件加入 resources
static func _pda_flush_stack(stack: Array[RandomEvent], resources: Array[Resource]) -> void:
    while not stack.is_empty():
        var event = stack.pop_back()
        if stack.is_empty() and validate_event(event):
            resources.append(event)

# 扁平数据解析（flags / trait / state_transistor），逐行独立解析
# 🚨 接收 String 类型 data_type，用字符串 match 避免 @tool 模式下 enum 跨脚本解析异常
static func _parse_flat_data(csv_data: Array[Dictionary], data_type: String) -> Array[Resource]:
    var resources: Array[Resource] = []
    for i in range(csv_data.size()):
        var row = csv_data[i]
        var resource: Resource = null
        
        match data_type:
            "flag":
                var flag = parse_flag(row)
                if flag and validate_flag(flag):
                    resource = flag
                else:
                    Logging.info("Warning: Failed to parse flag at row %d" % (i + 1))
            "trait":
                var trait_ = parse_trait(row)
                if trait_ and validate_trait(trait_):
                    resource = trait_
                else:
                    Logging.info("Warning: Failed to parse trait at row %d" % (i + 1))
            "state_transistor":
                var transistor = parse_state_transistor(row)
                if transistor and validate_state_transistor(transistor):
                    resource = transistor
                else:
                    Logging.info("Warning: Failed to parse state_transistor at row %d" % (i + 1))
            _:
                Logging.err("_parse_flat_data: 未知的 data_type 字符串: '%s' 💀" % data_type)
                continue
        
        if resource:
            resources.append(resource)
    
    return resources


# ════════════════════════════════════════════════════════════
# 🆕 Resource Converter CSV 解析器
# 解析 data/1_core_rules/resource_converters.csv
# 每一行生成 4 个 ActionArchetype + 1 个 Action .tres
# ════════════════════════════════════════════════════════════

const ActionArchetypeCls = preload("res://core/model/action_archetype.gd")
const DeferConfigCls = preload("res://model/defer_config.gd")
const ChoiceResultCls = preload("res://model/choice_result.gd")
const PushEventOperatorCls = preload("res://core/operators/push_event_operator.gd")


## 解析 resource_converter CSV 数据
## 返回 Array[Resource]：包含 Action .tres + ActionArchetype .tres
## ActionArchetype 会保存到 data/1_core_rules/archetypes/ 目录，运行时由 Database 加载
static func _parse_resource_converter(csv_data: Array[Dictionary]) -> Array[Resource]:
    var resources: Array[Resource] = []
    if csv_data.is_empty():
        Logging.warn("[resource_converter] CSV 数据为空，跳过")
        return resources

    for i in range(csv_data.size()):
        var row = csv_data[i]
        var uuid = str(row.get("uuid", "")).strip_edges()
        if uuid.is_empty():
            Logging.warn("[resource_converter] row %d: uuid 为空，跳过" % (i + 1))
            continue

        Logging.info("[resource_converter] 解析行 %d: uuid=%s" % [i + 1, uuid])

        # ── 1. 解析 context 字段 ──
        var context_str = str(row.get("context", "")).strip_edges()
        var ctx = _parse_converter_context(context_str)

        # ── 2. 创建 4 个 ActionArchetype，加入 resources 数组 ──
        var cost_dsl = str(row.get("cost_dsl", "")).strip_edges()
        var success_dsl = str(row.get("success_dsl", "")).strip_edges()
        var failure_dsl = str(row.get("failure_dsl", "")).strip_edges()
        var defer_dsl = str(row.get("defer_dsl", "")).strip_edges()

        var cost_arch: ActionArchetypeCls
        var success_arch: ActionArchetypeCls
        var failure_arch: ActionArchetypeCls
        var defer_arch: ActionArchetypeCls

        if not cost_dsl.is_empty():
            cost_arch = ActionArchetypeCls.create("%s_cost" % uuid, "%s.cost" % uuid, uuid, "cost", cost_dsl, "cost")
            cost_arch.resource_path = "res://data/1_core_rules/archetypes/%s_cost.tres" % uuid
            resources.append(cost_arch)
        if not success_dsl.is_empty():
            success_arch = ActionArchetypeCls.create("%s_success" % uuid, "%s.success" % uuid, uuid, "success", success_dsl, "success")
            success_arch.resource_path = "res://data/1_core_rules/archetypes/%s_success.tres" % uuid
            resources.append(success_arch)
        if not failure_dsl.is_empty():
            failure_arch = ActionArchetypeCls.create("%s_failure" % uuid, "%s.failure" % uuid, uuid, "failure", failure_dsl, "failure")
            failure_arch.resource_path = "res://data/1_core_rules/archetypes/%s_failure.tres" % uuid
            resources.append(failure_arch)
        if not defer_dsl.is_empty():
            defer_arch = ActionArchetypeCls.create("%s_defer" % uuid, "%s.defer" % uuid, uuid, "defer", defer_dsl, "defer")
            defer_arch.resource_path = "res://data/1_core_rules/archetypes/%s_defer.tres" % uuid
            resources.append(defer_arch)

        # ── 3. 构建 Action 资源 ──
        var action = _build_action_from_row(row, ctx, cost_arch, success_arch, failure_arch, defer_arch)
        if action:
            resources.append(action)
            Logging.info("[resource_converter] 生成 Action: %s" % uuid)
        else:
            Logging.err("[resource_converter] 生成 Action 失败: %s" % uuid)

    Logging.info("[resource_converter] 解析完成，共 %d 个 Resource" % resources.size())
    return resources


## 解析 context 字段 → Dictionary
## 格式: key1=val1|key2=val2|...
static func _parse_converter_context(ctx_str: String) -> Dictionary:
    var ctx := {
        "fallback_event": "",
        "failed_fallback": "",
        "lock_narrative": "",
        "defer_xun": "",
        "ap_cost_per_xun": "",
        "override_action": "",
        "defer_success_event": "",
    }
    if ctx_str.is_empty():
        return ctx

    var fields = ctx_str.split("|")
    for field in fields:
        field = field.strip_edges()
        if field.is_empty():
            continue
        var eq_idx = field.find("=")
        if eq_idx == -1:
            Logging.warn("[resource_converter] context 字段缺少 '=': %s" % field)
            continue
        var key = field.substr(0, eq_idx).strip_edges()
        var value = field.substr(eq_idx + 1).strip_edges()

        match key:
            "fallback_event":
                ctx.fallback_event = value
            "failed_fallback":
                ctx.failed_fallback = value
            "lock_narrative":
                ctx.lock_narrative = value
            "defer_xun":
                ctx.defer_xun = value
            "ap_cost_per_xun":
                ctx.ap_cost_per_xun = value
            "override_action":
                ctx.override_action = value
            "defer_success_event":
                ctx.defer_success_event = value
            _:
                Logging.info("[resource_converter] 未知 context key: %s = %s" % [key, value])

    return ctx


## 构建 Action Resource
static func _build_action_from_row(row: Dictionary, ctx: Dictionary,
        cost_arch, success_arch, failure_arch, defer_arch) -> Resource:
    var action_cls = preload("res://core/model/action.gd")
    var action: Resource = action_cls.new()
    if not action:
        Logging.err("[resource_converter] 无法实例化 Action 类")
        return null

    var uuid = str(row.get("uuid", "")).strip_edges()
    var name = str(row.get("name", "")).strip_edges()
    var required_place = str(row.get("required_place", "")).strip_edges()
    var description = str(row.get("description", "")).strip_edges()
    var day_consumed_str = str(row.get("day_consumed", "0")).strip_edges()
    var possibility = str(row.get("possibility", "l_success_rate")).strip_edges()
    var parent_action = str(row.get("parent_action", "")).strip_edges()
    var custom_option = str(row.get("custom_option", "")).strip_edges()

    action.uuid = uuid
    action.name = name
    action.required_place = required_place
    action.description = description
    action.day_consumed = day_consumed_str.to_float()
    action.possibility = possibility
    action.fallback_event_uuid = ctx.get("fallback_event", "")
    action.lock_narrative = ctx.get("lock_narrative", "")
    action.override_action = ctx.get("override_action", "")

    # 🆕 设置 resource_path 用于按父行动分目录保存
    if not parent_action.is_empty():
        action.resource_path = "res://data/3_actions_pool/actions/%s/%s.tres" % [parent_action, uuid]
    else:
        action.resource_path = "res://data/3_actions_pool/actions/%s.tres" % uuid

    # ── action_tags ──
    var tags_str = str(row.get("action_tags", "")).strip_edges()
    if not tags_str.is_empty():
        var tag_strs = tags_str.split(",")
        var tags: Array[int] = []
        for ts in tag_strs:
            var t = ts.strip_edges().to_int()
            if t >= 0:
                tags.append(t)
        action._action_tags = tags

    # ── archetype_uuid: 指向 success archetype（兼容旧 action.gd 逻辑）──
    if success_arch != null:
        action.archetype_uuid = "%s_success" % uuid

    # ── failed_result ──
    var failed_fallback = ctx.get("failed_fallback", "")
    if not failed_fallback.is_empty():
        var cr = ChoiceResultCls.new()
        var push_op = PushEventOperatorCls.new()
        push_op.event_key = failed_fallback
        cr.operators.append(push_op)
        action.failed_result = cr

    # ── defer_config ──
    var defer_xun = ctx.get("defer_xun", "")
    var ap_cost = ctx.get("ap_cost_per_xun", "")
    if not defer_xun.is_empty() or not ap_cost.is_empty():
        var dc = DeferConfigCls.new()
        dc.xun_defered = defer_xun
        dc.ap_cost = ap_cost
        if defer_arch != null:
            dc.used_resource_archetype = "%s_defer" % uuid
        if not failed_fallback.is_empty():
            dc.failed_fallback = failed_fallback
        var defer_success_event = ctx.get("defer_success_event", "")
        if not defer_success_event.is_empty():
            dc.defer_success_event = defer_success_event
        action.defer_config = dc

    # ── custom_option 硬编码处理 ──
    if not custom_option.is_empty():
        _apply_custom_option(action, custom_option, uuid, row)

    return action


## 处理 custom_option 字段：硬编码注入特殊 operator/requirement
static func _apply_custom_option(action: Resource, custom_option: String, uuid: String, row: Dictionary) -> void:
    Logging.info("[resource_converter] custom_option: %s for %s" % [custom_option, uuid])

    match custom_option:
        "consume_leverage":
            # 注入 ConsumeRandomLeverageOperator 到 action_results
            var leverage_op_cls = preload("res://core/operators/consume_random_leverage_operator.gd")
            var op = leverage_op_cls.new()
            if action.action_results == null:
                action.action_results = []
            action.action_results.append(op)
            Logging.info("[resource_converter] %s: 注入 ConsumeRandomLeverageOperator" % uuid)

        "poem_selector:fame", "poem_selector:money", "poem_selector:baiye", "poem_selector:xing_wang":
            # 注入 PoemRewardOperator + PoemRequirement
            var mode = custom_option.trim_prefix("poem_selector:")
            var poem_reward_cls = preload("res://core/operators/poem_reward_operator.gd")
            var poem_req_cls = preload("res://core/requirements/poem_requirement.gd")

            var reward_op = poem_reward_cls.new()
            reward_op.mode = mode
            reward_op.show_hint_on_reward = true

            var req = poem_req_cls.new()
            # accepted_poem_types 是 Array[ENUMS.POEM_TYPE]（类型化数组，默认已为空）

            if action.action_results == null:
                action.action_results = []
            action.action_results.append(reward_op)

            if action.aciton_requirements == null:
                action.aciton_requirements = []
            action.aciton_requirements.append(req)

            Logging.info("[resource_converter] %s: 注入 PoemRewardOperator(mode=%s) + PoemRequirement" % [uuid, mode])

        _:
            Logging.warn("[resource_converter] 未知 custom_option: %s for %s" % [custom_option, uuid])
