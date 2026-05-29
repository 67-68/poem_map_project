class_name MicroDSLParser extends GDScript

# ═══════════════════════════════════════════════════════
# MicroDSLParser — DSL 基础元素解析器
#
# 支持的两种语法模式：
#   1. 【新语法 - 推荐】命名参数函数调用格式
#      prop_gt(name="money", val=50)
#      trait_has(name="official")
#      flag_bool_set(name="xxx", val=true)
#      prop_add(name="money", val=100), trait_add(name="corrupt")
#
#   2. 【旧语法 - deprecated】冒号分割格式
#      prop:money:>50
#      trait:has:official
#      flag:bool:add:xxx
#      prop:money:-100,trait:add:corrupt
#
# 新语法使用 NamedDSLParser 核心解析器
# 旧语法保留为 fallback，解析时会打印 deprecation warning
# ═══════════════════════════════════════════════════════

# ─── 函数名常量 ───
# Requirements
const FUNC_PROP_GT := "prop_gt"
const FUNC_PROP_LT := "prop_lt"
const FUNC_TRAIT_HAS := "trait_has"
const FUNC_TRAIT_NOT_HAS := "trait_not_has"
const FUNC_FLAG_BOOL_HAS := "flag_bool_has"
const FUNC_FLAG_BOOL_NOT_HAS := "flag_bool_not_has"
const FUNC_FLAG_STR_IS := "flag_str_is"
const FUNC_FLAG_STR_NOT := "flag_str_not"
const FUNC_FLAG_INT_GT := "flag_int_gt"
const FUNC_FLAG_INT_LT := "flag_int_lt"

# Consequence operators
const FUNC_PROP_ADD := "prop_add"
const FUNC_PROP_SUB := "prop_sub"
const FUNC_PROP_SET := "prop_set"
const FUNC_TRAIT_ADD := "trait_add"
const FUNC_TRAIT_REMOVE := "trait_remove"
const FUNC_EMO_ADD := "emo_add"
const FUNC_EMO_SUB := "emo_sub"
const FUNC_EMO_SET := "emo_set"
const FUNC_FLAG_BOOL_SET := "flag_bool_set"
const FUNC_FLAG_BOOL_REPLACE := "flag_bool_replace"
const FUNC_FLAG_STR_SET := "flag_str_set"
const FUNC_FLAG_STR_APPEND := "flag_str_append"
const FUNC_FLAG_INT_SET := "flag_int_set"
const FUNC_FLAG_INT_APPEND := "flag_int_append"

# ──────────────────────────────────────────────
# Tags
# ──────────────────────────────────────────────

# 解析触发标签格式：domain:subcategory:category:specific_attribute (4段)
# 新格式也支持: tag("actor:status:temporary:drunk")
# 但 tag 本身是 4 段式 URL，不是函数调用，保持原样
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
			Logging.warn("标签格式无效: %s，期望格式: domain:category:type:specific" % clean_tag)
			continue
			
		parsed_tags.append(clean_tag)
	
	return parsed_tags

# ──────────────────────────────────────────────
# 统一入口：根据字符串内容自动选择新旧语法
# ──────────────────────────────────────────────

# 检测字符串是否使用新语法（函数调用格式）
static func _is_new_syntax(data: String) -> bool:
	# 新语法特征：以字母开头，包含 ( 且 ) 在末尾附近
	# 旧语法特征：以 type: 开头（prop:/trait:/flag:/emo:）
	data = data.strip_edges()
	if data.is_empty():
		return false
	# 如果以 prop:/trait:/flag:/emo: 开头 → 旧语法
	if data.begins_with("prop:") or data.begins_with("trait:") or \
	   data.begins_with("flag:") or data.begins_with("emo:"):
		return false
	# 如果包含 ( 且不以下述前缀开头 → 新语法
	if data.contains("(") and data.contains(")"):
		return true
	return false

# ──────────────────────────────────────────────
# Property Requirement
# ──────────────────────────────────────────────

# 新语法: prop_gt(name="money", val=50)
#         prop_lt(name="literary_fame", val=30)
# 旧语法: prop:money:>50
static func parse_property_requirement(data: String) -> PropertyRequirement:
	if _is_new_syntax(data):
		return _parse_property_requirement_new(data)
	else:
		Logging.warn("⚠ 旧语法已弃用，请迁移到新语法: %s" % data)
		return _parse_property_requirement_old(data)

static func _parse_property_requirement_new(data: String) -> PropertyRequirement:
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("属性需求解析失败（新语法）: %s" % data)
		return null
	
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	
	if name.is_empty():
		Logging.err("属性需求缺少 name 参数: %s" % data)
		return null
	
	match parsed.func_name:
		FUNC_PROP_GT:
			return _create_property_requirement(name, val, REQ_OPERATOR.COMPARE.GREATER_THAN)
		FUNC_PROP_LT:
			return _create_property_requirement(name, val, REQ_OPERATOR.COMPARE.LESS_THAN)
		_:
			Logging.err("未知的属性需求函数: %s，期望 prop_gt 或 prop_lt" % parsed.func_name)
			return null

static func _parse_property_requirement_old(data: String) -> PropertyRequirement:
	var parts = data.split(':')
	if parts.size() != 3:
		push_error("属性需求格式无效: %s，期望: prop:property_name:>value" % data)
		return null
	
	if parts[0] != "prop":
		push_error("属性需求必须以 'prop:' 开头: %s" % data)
		return null
	
	var property_name = parts[1]
	var operator_str = parts[2]
	
	if operator_str.begins_with('>'):
		var value = operator_str.substr(1).to_int()
		return _create_property_requirement(property_name, value, REQ_OPERATOR.COMPARE.GREATER_THAN)
	elif operator_str.begins_with('<'):
		var value = operator_str.substr(1).to_int()
		return _create_property_requirement(property_name, value, REQ_OPERATOR.COMPARE.LESS_THAN)
	else:
		push_error("属性需求操作符无效: %s，期望 > 或 <" % operator_str)
		return null

# ──────────────────────────────────────────────
# Trait Requirement
# ──────────────────────────────────────────────

# 新语法: trait_has(name="official")
#         trait_not_has(name="corrupt")
# 旧语法: trait:has:official
static func parse_trait_requirement(data: String) -> BaseRequirements:
	if _is_new_syntax(data):
		return _parse_trait_requirement_new(data)
	else:
		Logging.warn("⚠ 旧语法已弃用，请迁移到新语法: %s" % data)
		return _parse_trait_requirement_old(data)

static func _parse_trait_requirement_new(data: String) -> BaseRequirements:
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("特性需求解析失败（新语法）: %s" % data)
		return null
	
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("特性需求缺少 name 参数: %s" % data)
		return null
	
	match parsed.func_name:
		FUNC_TRAIT_HAS:
			return _create_trait_has_requirement(name, true)
		FUNC_TRAIT_NOT_HAS:
			return _create_trait_has_requirement(name, false)
		_:
			Logging.err("未知的特性需求函数: %s，期望 trait_has 或 trait_not_has" % parsed.func_name)
			return null

static func _parse_trait_requirement_old(data: String) -> BaseRequirements:
	var parts = data.split(':')
	if parts.size() != 3:
		push_error("特性需求格式无效: %s，期望: trait:has/not_has:trait_name" % data)
		return null

	if parts[0] != "trait":
		push_error("特性需求必须以 'trait:' 开头: %s" % data)
		return null

	var operator = parts[1]
	var trait_name = parts[2]

	if operator == "has":
		return _create_trait_has_requirement(trait_name, true)
	elif operator == "not_has":
		return _create_trait_has_requirement(trait_name, false)
	else:
		push_error("特性需求操作符无效: %s，期望 'has' 或 'not_has'" % operator)
		return null

# ──────────────────────────────────────────────
# Flag Requirement
# ──────────────────────────────────────────────

# 新语法:
#   flag_bool_has(name="xxx")
#   flag_bool_not_has(name="xxx")
#   flag_str_is(name="xxx", val="张三")
#   flag_str_not(name="xxx", val="张三")
#   flag_int_gt(name="xxx", val=100)
#   flag_int_lt(name="xxx", val=50)
# 旧语法:
#   flag:bool:has:xxx
#   flag:str:is:xxx:张三
#   flag:int:>:flag_score:100
static func parse_flag_requirement(data: String) -> FlagRequirement:
	if _is_new_syntax(data):
		return _parse_flag_requirement_new(data)
	else:
		Logging.warn("⚠ 旧语法已弃用，请迁移到新语法: %s" % data)
		return _parse_flag_requirement_old(data)

static func _parse_flag_requirement_new(data: String) -> FlagRequirement:
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("标志位需求解析失败（新语法）: %s" % data)
		return null
	
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("标志位需求缺少 name 参数: %s" % data)
		return null
	
	var req = FlagRequirement.new()
	req.flag_id = name
	
	match parsed.func_name:
		FUNC_FLAG_BOOL_HAS:
			req.type = "bool"
			req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
			req.value = true
		FUNC_FLAG_BOOL_NOT_HAS:
			req.type = "bool"
			req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
			req.value = true
		FUNC_FLAG_STR_IS:
			req.type = "str"
			req.operator = REQ_OPERATOR.COMPARE.EQUAL
			req.value = NamedDSLParser.get_str_param(parsed, "val")
		FUNC_FLAG_STR_NOT:
			req.type = "str"
			req.operator = REQ_OPERATOR.COMPARE.NOT_EQUAL
			req.value = NamedDSLParser.get_str_param(parsed, "val")
		FUNC_FLAG_INT_GT:
			req.type = "int"
			req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
			req.value = NamedDSLParser.get_int_param(parsed, "val")
		FUNC_FLAG_INT_LT:
			req.type = "int"
			req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
			req.value = NamedDSLParser.get_int_param(parsed, "val")
		_:
			Logging.err("未知的标志位需求函数: %s" % parsed.func_name)
			return null
	
	return req

static func _parse_flag_requirement_old(data: String) -> FlagRequirement:
	var parts = data.split(':')
	if parts.size() < 4:
		push_error("标志位需求格式无效: %s，期望: flag:type:operator:flag_id" % data)
		return null

	if parts[0] != "flag":
		push_error("标志位需求必须以 'flag:' 开头: %s" % data)
		return null

	var flag_type = parts[1]
	var operator_str = parts[2]
	var flag_id = parts[3]

	var req = FlagRequirement.new()
	req.type = flag_type
	req.flag_id = flag_id

	match flag_type:
		"bool":
			if operator_str == "has":
				req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
				req.value = true
			elif operator_str == "not_has":
				req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
				req.value = true
			else:
				push_error("布尔标志位操作符无效: %s，期望 'has' 或 'not_has'" % operator_str)
				return null
		"str":
			if operator_str == "is":
				req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
				req.value = flag_id  # 🚨 旧语法 bug: 这里本应是 val，但误用了 flag_id
			elif operator_str == "is_not":
				req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
				req.value = flag_id
			else:
				push_error("字符串标志位操作符无效: %s，期望 'is' 或 'is_not'" % operator_str)
				return null
		"int":
			if parts.size() < 5:
				push_error("整数标志位需求格式无效: 期望 'flag:int:operator:flag_id:value' (5段), 收到: %s" % data)
				return null
			var int_flag_id = parts[3]
			var int_value = parts[4].to_int()
			req.flag_id = int_flag_id
			req.value = int_value
			if operator_str == ">":
				req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
			elif operator_str == "<":
				req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
			else:
				push_error("整数标志位操作符无效: %s，期望 '>' 或 '<'" % operator_str)
				return null
		_:
			push_error("标志位类型无效: %s，期望 'bool', 'str', 或 'int'" % flag_type)
			return null

	return req

# ──────────────────────────────────────────────
# Consequence Operators
# ──────────────────────────────────────────────

# 解析结果操作符列表
# 新语法: prop_add(name="money", val=100), trait_add(name="corrupt")
# 旧语法: prop:money:-100,trait:add:corrupt
static func parse_consequence_operators(data: String) -> Array[BaseOperator]:
	var operators: Array[BaseOperator] = []
	
	if data.is_empty():
		return operators
	
	# 检测是否是旧语法（整体判断，因为逗号分隔多个操作符）
	var data_stripped = data.strip_edges()
	# 如果第一个表达式以 prop:/trait:/flag:/emo: 开头 → 旧语法
	if data_stripped.begins_with("prop:") or data_stripped.begins_with("trait:") or \
	   data_stripped.begins_with("flag:") or data_stripped.begins_with("emo:"):
		Logging.warn("⚠ 旧语法已弃用，请迁移到新语法: %s" % data)
		return _parse_consequence_operators_old(data)
	
	# 新语法：按顶级逗号分割
	var expressions = NamedDSLParser.split_expressions(data)
	for expr in expressions:
		var op = _parse_single_consequence_new(expr)
		if op:
			operators.append(op)
	
	return operators

static func _parse_single_consequence_new(data: String) -> BaseOperator:
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("结果操作符解析失败（新语法）: %s" % data)
		return null
	
	match parsed.func_name:
		# ── Property operators ──
		FUNC_PROP_ADD:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("prop_add 缺少 name 参数: %s" % data)
				return null
			return _create_property_operator(name, val)
		FUNC_PROP_SUB:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("prop_sub 缺少 name 参数: %s" % data)
				return null
			return _create_property_operator(name, -val)
		FUNC_PROP_SET:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("prop_set 缺少 name 参数: %s" % data)
				return null
			# set 需要特殊处理：直接设置属性值
			var op = PropertyOperator.new()
			op.str_props = name
			op.value = val
			return op
		
		# ── Trait operators ──
		FUNC_TRAIT_ADD:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			if name.is_empty():
				Logging.err("trait_add 缺少 name 参数: %s" % data)
				return null
			return _create_trait_operator(name, REQ_OPERATOR.CRUD.ADD)
		FUNC_TRAIT_REMOVE:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			if name.is_empty():
				Logging.err("trait_remove 缺少 name 参数: %s" % data)
				return null
			return _create_trait_operator(name, REQ_OPERATOR.CRUD.REMOVE)
		
		# ── Emotion operators ──
		FUNC_EMO_ADD:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("emo_add 缺少 name 参数: %s" % data)
				return null
			return _create_emotion_operator(name, abs(val))
		FUNC_EMO_SUB:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("emo_sub 缺少 name 参数: %s" % data)
				return null
			return _create_emotion_operator(name, -abs(val))
		FUNC_EMO_SET:
			var name = NamedDSLParser.get_str_param(parsed, "name")
			var val = NamedDSLParser.get_int_param(parsed, "val")
			if name.is_empty():
				Logging.err("emo_set 缺少 name 参数: %s" % data)
				return null
			# set 直接赋值
			var op = EmotionOperator.new()
			op.str_emotion = name
			op.value = val
			return op
		
		# ── Flag operators ──
		FUNC_FLAG_BOOL_SET:
			return _create_flag_operator_bool_set(parsed, data)
		FUNC_FLAG_BOOL_REPLACE:
			return _create_flag_operator_replace(parsed, data)
		FUNC_FLAG_STR_SET:
			return _create_flag_operator_str_set(parsed, data)
		FUNC_FLAG_STR_APPEND:
			return _create_flag_operator_str_append(parsed, data)
		FUNC_FLAG_INT_SET:
			return _create_flag_operator_int_set(parsed, data)
		FUNC_FLAG_INT_APPEND:
			return _create_flag_operator_int_append(parsed, data)
		
		_:
			Logging.err("未知的结果操作符函数: %s" % parsed.func_name)
			return null

# ── Flag operator 辅助创建方法 ──

static func _create_flag_operator_bool_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_bool_param(parsed, "val", true)
	if name.is_empty():
		Logging.err("flag_bool_set 缺少 name 参数: %s" % data)
		return null
	var op = FlagOperator.new()
	op.type = "bool"
	op.operation = "set"
	op.flag_id = name
	op.value = val
	return op

static func _create_flag_operator_replace(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var from = NamedDSLParser.get_str_param(parsed, "from")
	var to = NamedDSLParser.get_str_param(parsed, "to")
	if from.is_empty() or to.is_empty():
		Logging.err("flag_bool_replace 缺少 from/to 参数: %s" % data)
		return null
	return OperatorFactory.create_flag_replace_operator(from, to)

static func _create_flag_operator_str_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_str_param(parsed, "val")
	if name.is_empty():
		Logging.err("flag_str_set 缺少 name 参数: %s" % data)
		return null
	var op = FlagOperator.new()
	op.type = "str"
	op.operation = "set"
	op.flag_id = name
	op.value = val
	return op

static func _create_flag_operator_str_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_str_param(parsed, "val")
	if name.is_empty():
		Logging.err("flag_str_append 缺少 name 参数: %s" % data)
		return null
	var op = FlagOperator.new()
	op.type = "str"
	op.operation = "append"
	op.flag_id = name
	op.value = val
	return op

static func _create_flag_operator_int_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("flag_int_set 缺少 name 参数: %s" % data)
		return null
	var op = FlagOperator.new()
	op.type = "int"
	op.operation = "set"
	op.flag_id = name
	op.value = val
	return op

static func _create_flag_operator_int_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("flag_int_append 缺少 name 参数: %s" % data)
		return null
	var op = FlagOperator.new()
	op.type = "int"
	op.operation = "append"
	op.flag_id = name
	op.value = val
	return op

# ──────────────────────────────────────────────
# 旧语法 consequence operator 解析（deprecated fallback）
# ──────────────────────────────────────────────

static func _parse_consequence_operators_old(data: String) -> Array[BaseOperator]:
	var operators: Array[BaseOperator] = []
	var parts = data.split(',')

	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part.is_empty():
			continue

		var op_parts = clean_part.split(':')
		if op_parts.size() < 3:
			Logging.warn("结果操作符格式无效: %s，期望: type:action:value" % clean_part)
			continue

		var type = op_parts[0]
		var action = op_parts[1]
		var value = op_parts[2]

		if type == "prop":
			var operator = _create_property_operator(action, value.to_int())
			if operator:
				operators.append(operator)
		elif type == "trait":
			var operator = _create_trait_operator_old(action, value)
			if operator:
				operators.append(operator)
		elif type == "emo":
			var operator = _create_emotion_operator_old(action, value)
			if operator:
				operators.append(operator)
		elif type == "flag":
			var operator = _parse_flag_operator_old(clean_part)
			if operator:
				operators.append(operator)
		else:
			Logging.warn("未知的结果操作符类型: %s" % type)

	return operators

# ──────────────────────────────────────────────
# 辅助方法：创建各种操作符/需求对象
# ──────────────────────────────────────────────

static func _create_property_requirement(property_name: String, value: int, operator: REQ_OPERATOR.COMPARE) -> PropertyRequirement:
	var req = PropertyRequirement.new()
	req.property = property_name
	req.value = value
	req.operator = operator
	return req

static func _create_trait_has_requirement(trait_name: String, _should_have: bool) -> BaseRequirements:
	var req = TraitRequirement.new()
	req.trait_name = trait_name
	if _should_have:
		req.operator = REQ_OPERATOR.EXIST.HAS
	else:
		req.operator = REQ_OPERATOR.EXIST.NOT_HAS
	return req

static func _create_property_operator(action: String, value: int) -> BaseOperator:
	var operator = PropertyOperator.new()
	operator.str_props = action
	operator.value = value
	return operator

static func _create_trait_operator(trait_name: String, operation: REQ_OPERATOR.CRUD) -> BaseOperator:
	var operator = TraitOperator.new()
	operator.operator = operation
	operator.str_traits = trait_name
	var enum_trait = ENUMS.from_traits_str(trait_name)
	if enum_trait >= 0:
		operator._trait_key = enum_trait
	return operator

static func _create_trait_operator_old(action: String, trait_name: String) -> BaseOperator:
	var operator = TraitOperator.new()
	if action == "add":
		operator.operator = REQ_OPERATOR.CRUD.ADD
	elif action == "remove":
		operator.operator = REQ_OPERATOR.CRUD.REMOVE
	else:
		Logging.warn("未知的特性操作: %s，期望 'add' 或 'remove'" % action)
		return null
	operator.str_traits = trait_name
	var enum_trait = ENUMS.from_traits_str(trait_name)
	if enum_trait >= 0:
		operator._trait_key = enum_trait
	return operator

static func _create_emotion_operator(emotion_name: String, value: int) -> BaseOperator:
	var operator = EmotionOperator.new()
	operator.str_emotion = emotion_name
	operator.value = value
	return operator

static func _create_emotion_operator_old(action: String, value_str: String) -> BaseOperator:
	var value = value_str.to_int()
	var operator = EmotionOperator.new()
	operator.str_emotion = action
	if value_str.begins_with('+') or value_str.begins_with('-'):
		operator.value = value
	return operator

# 旧语法 flag operator 解析
static func _parse_flag_operator_old(data: String) -> BaseOperator:
	# 先检查是否是替换操作 flag:bool:{flag-a-uuid}->{flag_b_uuid}
	if data.contains('->') and data.begins_with("flag:bool:"):
		return _parse_flag_replace_operator_old(data)

	var parts = data.split(':')
	if parts[0] != "flag":
		push_error("Flag 操作符必须以 'flag:' 开头: %s" % data)
		return null

	var flag_type = parts[1]
	var action = parts[2]

	var operator = FlagOperator.new()
	operator.type = flag_type

	match flag_type:
		"bool":
			if action == "add":
				operator.operation = "set"
				operator.value = true
				operator.flag_id = parts[3]
			elif action == "remove":
				operator.operation = "set"
				operator.value = false
				operator.flag_id = parts[3]
			else:
				push_error("布尔 Flag 操作无效: %s，期望 'add' 或 'remove'" % action)
				return null
		"int":
			if parts.size() < 5:
				push_error("整数 Flag 操作格式无效: 期望 'flag:int:add/set:flag_id:value'" % data)
				return null
			operator.flag_id = parts[3]
			if action == "add":
				operator.operation = "append"
				operator.value = parts[4].to_int()
			elif action == "set":
				operator.operation = "set"
				operator.value = parts[4].to_int()
			else:
				push_error("整数 Flag 操作无效: %s，期望 'add' 或 'set'" % action)
				return null
		"str":
			if action == "set" and parts.size() == 5:
				operator.flag_id = parts[3]
				operator.operation = "set"
				operator.value = parts[4]
			else:
				push_error("字符串 Flag 操作无效: 期望 'flag:str:set:name:value'" % data)
				return null
		_:
			push_error("Flag 类型无效: %s，期望 'bool', 'str', 或 'int'" % flag_type)
			return null

	return operator

static func _parse_flag_replace_operator_old(data: String) -> BaseOperator:
	if not data.begins_with("flag:bool:"):
		push_error("Flag 替换操作格式无效: %s" % data)
		return null

	var replace_part = data.substr(10)
	var replace_parts = replace_part.split('->')
	if replace_parts.size() != 2:
		push_error("Flag 替换操作格式无效: %s" % data)
		return null

	var to_be_replaced_flag_id = replace_parts[0].strip_edges()
	var replace_with_flag_id = replace_parts[1].strip_edges()
	return OperatorFactory.create_flag_replace_operator(to_be_replaced_flag_id, replace_with_flag_id)
