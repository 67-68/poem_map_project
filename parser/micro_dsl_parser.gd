class_name MicroDSLParser extends GDScript

# ═══════════════════════════════════════════════════════
# MicroDSLParser — DSL 基础元素解析器
#
# 仅支持一种语法模式：
#   1. 【新语法 - 唯一】命名参数函数调用格式
#      prop_gt(name="money", val=50)
#      trait_has(name="official")
#      flag_bool_set(name="xxx", val=true)
#      prop_add(name="money", val=100), trait_add(name="corrupt")
#
# 新语法使用 NamedDSLParser 核心解析器
# 旧语法（冒号分割格式）已完全移除，不再兼容
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
# Property Requirement
# ──────────────────────────────────────────────

# 新语法: prop_gt(name="money", val=50)
#         prop_lt(name="literary_fame", val=30)
static func parse_property_requirement(data: String) -> PropertyRequirement:
	return _parse_property_requirement_new(data)

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

# ──────────────────────────────────────────────
# Trait Requirement
# ──────────────────────────────────────────────

# 新语法: trait_has(name="official")
#         trait_not_has(name="corrupt")
static func parse_trait_requirement(data: String) -> BaseRequirements:
	return _parse_trait_requirement_new(data)

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
static func parse_flag_requirement(data: String) -> FlagRequirement:
	return _parse_flag_requirement_new(data)

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

# ──────────────────────────────────────────────
# Consequence Operators
# ──────────────────────────────────────────────

# 解析结果操作符列表
# 新语法: prop_add(name="money", val=100), trait_add(name="corrupt")
static func parse_consequence_operators(data: String) -> Array[BaseOperator]:
	var operators: Array[BaseOperator] = []
	
	if data.is_empty():
		return operators
	
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

static func _create_emotion_operator(emotion_name: String, value: int) -> BaseOperator:
	var operator = EmotionOperator.new()
	operator.str_emotion = emotion_name
	operator.value = value
	return operator
