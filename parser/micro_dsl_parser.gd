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
#
# 调度架构：
#   所有函数名→处理器的映射集中在 _requirement_dispatch 和
#   _consequence_dispatch 两个字典中。不再有散落的 match 块。
#   加新函数只需在字典中加一行。
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
const FUNC_PUSH_EVENT := "push_event"
const FUNC_POP_EVENT := "pop_event"
const FUNC_QUEUE_EVENT := "queue_event"

# ─────────────────────────────────────────────────────────────
# 中央调度注册表
# func_name → handler(parsed: ParseResult, raw: String) -> Variant
# ─────────────────────────────────────────────────────────────

static var _requirement_dispatch: Dictionary = {}
static var _consequence_dispatch: Dictionary = {}

static func _ensure_dispatch() -> void:
	if not _requirement_dispatch.is_empty():
		return
	
	# ── Requirements ──
	var rd = _requirement_dispatch
	rd[FUNC_PROP_GT] = func(p, r): return _exec_prop_req(p, r, REQ_OPERATOR.COMPARE.GREATER_THAN)
	rd[FUNC_PROP_LT] = func(p, r): return _exec_prop_req(p, r, REQ_OPERATOR.COMPARE.LESS_THAN)
	rd[FUNC_TRAIT_HAS] = func(p, r): return _exec_trait_req(p, r, true)
	rd[FUNC_TRAIT_NOT_HAS] = func(p, r): return _exec_trait_req(p, r, false)
	rd[FUNC_FLAG_BOOL_HAS] = func(p, r): return _exec_flag_req_bool(p, r, true)
	rd[FUNC_FLAG_BOOL_NOT_HAS] = func(p, r): return _exec_flag_req_bool(p, r, false)
	rd[FUNC_FLAG_STR_IS] = func(p, r): return _exec_flag_req_str(p, r, REQ_OPERATOR.COMPARE.EQUAL)
	rd[FUNC_FLAG_STR_NOT] = func(p, r): return _exec_flag_req_str(p, r, REQ_OPERATOR.COMPARE.NOT_EQUAL)
	rd[FUNC_FLAG_INT_GT] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.GREATER_THAN)
	rd[FUNC_FLAG_INT_LT] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.LESS_THAN)
	
	# ── Consequence Operators ──
	var cd = _consequence_dispatch
	cd[FUNC_PROP_ADD] = func(p, r): return _exec_prop_op(p, r, 1)
	cd[FUNC_PROP_SUB] = func(p, r): return _exec_prop_op(p, r, -1)
	cd[FUNC_PROP_SET] = func(p, r): return _exec_prop_op_set(p, r)
	cd[FUNC_TRAIT_ADD] = func(p, r): return _exec_trait_op(p, r, REQ_OPERATOR.CRUD.ADD)
	cd[FUNC_TRAIT_REMOVE] = func(p, r): return _exec_trait_op(p, r, REQ_OPERATOR.CRUD.REMOVE)
	cd[FUNC_EMO_ADD] = func(p, r): return _exec_emo_op(p, r, 1)
	cd[FUNC_EMO_SUB] = func(p, r): return _exec_emo_op(p, r, -1)
	cd[FUNC_EMO_SET] = func(p, r): return _exec_emo_op_set(p, r)
	cd[FUNC_FLAG_BOOL_SET] = func(p, r): return _create_flag_operator_bool_set(p, r)
	cd[FUNC_FLAG_BOOL_REPLACE] = func(p, r): return _create_flag_operator_replace(p, r)
	cd[FUNC_FLAG_STR_SET] = func(p, r): return _create_flag_operator_str_set(p, r)
	cd[FUNC_FLAG_STR_APPEND] = func(p, r): return _create_flag_operator_str_append(p, r)
	cd[FUNC_FLAG_INT_SET] = func(p, r): return _create_flag_operator_int_set(p, r)
	cd[FUNC_FLAG_INT_APPEND] = func(p, r): return _create_flag_operator_int_append(p, r)
	cd[FUNC_PUSH_EVENT] = func(p, r): return _exec_push_event_op(p, r)
	cd[FUNC_POP_EVENT] = func(p, r): return _exec_pop_event_op(p, r)
	cd[FUNC_QUEUE_EVENT] = func(p, r): return _exec_queue_event_op(p, r)

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

# ═══════════════════════════════════════════════════════════
# 统一入口（对外公开）
# ═══════════════════════════════════════════════════════════

# 解析单个需求表达式（统一入口）
# 输入: "prop_gt(name=money, val=50)" 或 "trait_has(name=official)"
# 返回: PropertyRequirement / TraitRequirement / FlagRequirement / null
static func parse_requirement(data: String) -> BaseRequirements:
	_ensure_dispatch()
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("需求解析失败: %s" % data)
		return null
	
	if _requirement_dispatch.has(parsed.func_name):
		return _requirement_dispatch[parsed.func_name].call(parsed, data)
	
	Logging.err("未知需求函数: %s" % data)
	return null

# 解析单个后果操作符表达式（统一入口）
# 输入: "prop_add(name=money, val=100)" 或 "trait_add(name=corrupt)"
# 返回: PropertyOperator / TraitOperator / EmotionOperator / FlagOperator / null
static func parse_operator(data: String) -> BaseOperator:
	_ensure_dispatch()
	var parsed = NamedDSLParser.parse_single(data)
	if parsed == null:
		Logging.err("操作符解析失败: %s" % data)
		return null
	
	if _consequence_dispatch.has(parsed.func_name):
		return _consequence_dispatch[parsed.func_name].call(parsed, data)
	
	Logging.err("未知操作符函数: %s" % data)
	return null

# ═══════════════════════════════════════════════════════════
# 旧公开接口（向后兼容，委托给统一入口）
# ═══════════════════════════════════════════════════════════

static func parse_property_requirement(data: String) -> PropertyRequirement:
	return parse_requirement(data) as PropertyRequirement

static func parse_trait_requirement(data: String) -> BaseRequirements:
	return parse_requirement(data)

static func parse_flag_requirement(data: String) -> FlagRequirement:
	return parse_requirement(data) as FlagRequirement

# 解析结果操作符列表
# 新语法: prop_add(name="money", val=100), trait_add(name="corrupt")
static func parse_consequence_operators(data: String) -> Array[BaseOperator]:
	var operators: Array[BaseOperator] = []
	
	if data.is_empty():
		return operators
	
	var expressions = NamedDSLParser.split_expressions(data)
	for expr in expressions:
		var op = parse_operator(expr)
		if op:
			operators.append(op)
	
	return operators

# ═══════════════════════════════════════════════════════════
# 内部处理器（需求）
# ═══════════════════════════════════════════════════════════

# Property Requirement（共享 prop_gt / prop_lt）
static func _exec_prop_req(parsed: NamedDSLParser.ParseResult, raw: String, compare_op: REQ_OPERATOR.COMPARE) -> PropertyRequirement:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	
	if name.is_empty():
		Logging.err("属性需求缺少 name 参数: %s" % raw)
		return null
	
	return _create_property_requirement(name, val, compare_op)

# Trait Requirement（共享 trait_has / trait_not_has）
static func _exec_trait_req(parsed: NamedDSLParser.ParseResult, raw: String, should_have: bool) -> BaseRequirements:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("特性需求缺少 name 参数: %s" % raw)
		return null
	
	return _create_trait_has_requirement(name, should_have)

# Flag Requirement: bool
static func _exec_flag_req_bool(parsed: NamedDSLParser.ParseResult, raw: String, is_has: bool) -> FlagRequirement:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("标志位需求缺少 name 参数: %s" % raw)
		return null
	
	var req = FlagRequirement.new()
	req.flag_id = name
	req.type = "bool"
	if is_has:
		req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
		req.value = true
	else:
		req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
		req.value = true
	return req

# Flag Requirement: str
static func _exec_flag_req_str(parsed: NamedDSLParser.ParseResult, raw: String, compare_op: REQ_OPERATOR.COMPARE) -> FlagRequirement:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("标志位需求缺少 name 参数: %s" % raw)
		return null
	
	var req = FlagRequirement.new()
	req.flag_id = name
	req.type = "str"
	req.operator = compare_op
	req.value = NamedDSLParser.get_str_param(parsed, "val")
	return req

# Flag Requirement: int
static func _exec_flag_req_int(parsed: NamedDSLParser.ParseResult, raw: String, compare_op: REQ_OPERATOR.COMPARE) -> FlagRequirement:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("标志位需求缺少 name 参数: %s" % raw)
		return null
	
	var req = FlagRequirement.new()
	req.flag_id = name
	req.type = "int"
	req.operator = compare_op
	req.value = NamedDSLParser.get_int_param(parsed, "val")
	return req

# ═══════════════════════════════════════════════════════════
# 内部处理器（后果操作符）
# ═══════════════════════════════════════════════════════════

# Property Operator: add / sub
static func _exec_prop_op(parsed: NamedDSLParser.ParseResult, raw: String, sign: int) -> PropertyOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("prop_add/sub 缺少 name 参数: %s" % raw)
		return null
	return _create_property_operator(name, val * sign)

# Property Operator: set
static func _exec_prop_op_set(parsed: NamedDSLParser.ParseResult, raw: String) -> PropertyOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("prop_set 缺少 name 参数: %s" % raw)
		return null
	var op = PropertyOperator.new()
	op.str_props = name
	op.value = val
	return op

# Trait Operator: add / remove
static func _exec_trait_op(parsed: NamedDSLParser.ParseResult, raw: String, operation: REQ_OPERATOR.CRUD) -> TraitOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("trait_add/remove 缺少 name 参数: %s" % raw)
		return null
	return _create_trait_operator(name, operation)

# Emotion Operator: add / sub（带 abs 保护）
static func _exec_emo_op(parsed: NamedDSLParser.ParseResult, raw: String, sign: int) -> EmotionOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("emo_add/sub 缺少 name 参数: %s" % raw)
		return null
	return _create_emotion_operator(name, abs(val) * sign)

# Emotion Operator: set
static func _exec_emo_op_set(parsed: NamedDSLParser.ParseResult, raw: String) -> EmotionOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("emo_set 缺少 name 参数: %s" % raw)
		return null
	var op = EmotionOperator.new()
	op.str_emotion = name
	op.value = val
	return op

# ──────────────────────────────────────────────
# Flag operator 辅助创建方法
# ──────────────────────────────────────────────

# 🚨 辅助方法：从 parsed.params["name"] 中提取 flag_id 或 target_flag_id_from_context
# 如果值是 DynamicRef，设置 target_flag_id_from_context；否则设置 flag_id
# 返回 false 表示缺少 name 参数
static func _resolve_flag_name(parsed: NamedDSLParser.ParseResult, op: FlagOperator, data: String) -> bool:
	var name_val = parsed.params.get("name")
	if name_val is NamedDSLParser.DynamicRef:
		op.target_flag_id_from_context = name_val.context_key
		Logging.info("MicroDSLParser: flag name 解析为动态引用 @%s" % name_val.context_key)
		return true
	else:
		var name = NamedDSLParser.get_str_param(parsed, "name")
		if name.is_empty():
			Logging.err("flag_* 缺少 name 参数: %s" % data)
			return false
		op.flag_id = name
		return true


static func _create_flag_operator_bool_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "bool"
	op.operation = "set"
	op.value = NamedDSLParser.get_bool_param(parsed, "val", true)
	
	if not _resolve_flag_name(parsed, op, data):
		return null
	
	return op

static func _create_flag_operator_replace(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var from = NamedDSLParser.get_str_param(parsed, "from")
	var to = NamedDSLParser.get_str_param(parsed, "to")
	if from.is_empty() or to.is_empty():
		Logging.err("flag_bool_replace 缺少 from/to 参数: %s" % data)
		return null
	return OperatorFactory.create_flag_replace_operator(from, to)

static func _create_flag_operator_str_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "str"
	op.operation = "set"
	op.value = NamedDSLParser.get_str_param(parsed, "val")
	
	if not _resolve_flag_name(parsed, op, data):
		return null
	
	return op

static func _create_flag_operator_str_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "str"
	op.operation = "append"
	op.value = NamedDSLParser.get_str_param(parsed, "val")
	
	if not _resolve_flag_name(parsed, op, data):
		return null
	
	return op

static func _create_flag_operator_int_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "int"
	op.operation = "set"
	op.value = NamedDSLParser.get_int_param(parsed, "val")
	
	if not _resolve_flag_name(parsed, op, data):
		return null
	
	return op

static func _create_flag_operator_int_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "int"
	op.operation = "append"
	op.value = NamedDSLParser.get_int_param(parsed, "val")
	
	if not _resolve_flag_name(parsed, op, data):
		return null
	
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


# ─── push_event / pop_event ─────────────────────────────────

static func _exec_push_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> PushEventOperator:
	var key = NamedDSLParser.get_str_param(parsed, "event_key")
	if key.is_empty():
		Logging.err("push_event 缺少 event_key 参数: %s" % raw)
		return null
	var op = PushEventOperator.new()
	op.event_key = key
	return op


static func _exec_pop_event_op(_parsed: NamedDSLParser.ParseResult, raw: String) -> PopEventOperator:
	return PopEventOperator.new()


# ─── queue_event ──────────────────────────────────────────────

static func _exec_queue_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> QueueEventOperator:
	var key = NamedDSLParser.get_str_param(parsed, "event_key")
	if key.is_empty():
		Logging.err("queue_event 缺少 event_key 参数: %s" % raw)
		return null
	var op = QueueEventOperator.new()
	op.event_key = key
	return op
