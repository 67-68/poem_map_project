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
const FUNC_EMO_GT := "emo_gt"
const FUNC_EMO_LT := "emo_lt"
const FUNC_TRAIT_HAS := "trait_has"
const FUNC_TRAIT_NOT_HAS := "trait_not_has"
const FUNC_FLAG_BOOL_HAS := "flag_bool_has"
const FUNC_FLAG_BOOL_NOT_HAS := "flag_bool_not_has"
const FUNC_FLAG_STR_IS := "flag_str_is"
const FUNC_FLAG_STR_NOT := "flag_str_not"
const FUNC_FLAG_INT_GT := "flag_int_gt"
const FUNC_FLAG_INT_LT := "flag_int_lt"
const FUNC_FLAG_INT_EQ := "flag_int_eq"
const FUNC_FLAG_INT_NE := "flag_int_ne"
const FUNC_POEM_HAS := "poem_has"

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
const FUNC_FLAG_INT_REDUCE_IF_ABOVE := "flag_int_reduce_if_above"

# Temp flag variants — 临时标志位，自动注册反向清理算子
const FUNC_TEMP_FLAG_BOOL_SET := "temp_flag_bool_set"
const FUNC_TEMP_FLAG_STR_SET := "temp_flag_str_set"
const FUNC_TEMP_FLAG_STR_APPEND := "temp_flag_str_append"
const FUNC_TIME_ADD := "time_add"

const FUNC_TEMP_FLAG_INT_SET := "temp_flag_int_set"
const FUNC_TEMP_FLAG_INT_APPEND := "temp_flag_int_append"
const FUNC_TEMP_FLAG_INT_REDUCE_IF_ABOVE := "temp_flag_int_reduce_if_above"

const FUNC_IMAGE_PRESENT := "image_present"
const FUNC_IMAGE_SLIDE := "image_slide"
const FUNC_IMAGE_SHATTER := "image_shatter"
const FUNC_IMAGE_FADE_OUT := "image_fade_out"
const FUNC_IMAGE_REMOVE := "image_remove"
const FUNC_OVERLAY_ANIM := "overlay_anim"

const FUNC_SCAN_AND_PUSH := "scan_and_push"
const FUNC_PUSH_EVENT := "push_event"
const FUNC_CONTEXT_KEY_PUSH_EVENT := "context_key_push_event"
const FUNC_POP_EVENT := "pop_event"
const FUNC_PUSH_FOCUSED_CHAT := "push_focused_chat"
const FUNC_CLEAR_SCHEDULED_EVENTS := "clear_scheduled_events"
const FUNC_QUEUE_EVENT := "queue_event"
const FUNC_RANDOM := "random"
const FUNC_RANDOM_PICK := "random_pick"
const FUNC_CONDITIONAL_RANDOM := "conditional_random"
const FUNC_CONTEXT_FETCH := "context_fetch"
const FUNC_NPC_BATCH_CHECK := "npc_batch_check"

# Custom operators — 飞花令玩家应答
const FUNC_IMAGINARY_LEVEL_REWARD := "imaginary_level_reward"
const FUNC_IMAGERY_ADD := "imagery_add"                      # 🆕 意象获取操作符
const FUNC_PLAY_TRANSITION := "play_transition"
const FUNC_LEVERAGE_ADD := "leverage_add"
const FUNC_INFO := "info"
const FUNC_ALL_EMO_SUB := "all_emo_sub"
const FUNC_ADD_SOCIAL_CREDIT := "add_social_credit"

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
	rd[FUNC_EMO_GT] = func(p, r): return _exec_emo_req(p, r, REQ_OPERATOR.COMPARE.GREATER_THAN)
	rd[FUNC_EMO_LT] = func(p, r): return _exec_emo_req(p, r, REQ_OPERATOR.COMPARE.LESS_THAN)
	rd[FUNC_TRAIT_HAS] = func(p, r): return _exec_trait_req(p, r, true)
	rd[FUNC_TRAIT_NOT_HAS] = func(p, r): return _exec_trait_req(p, r, false)
	rd[FUNC_FLAG_BOOL_HAS] = func(p, r): return _exec_flag_req_bool(p, r, true)
	rd[FUNC_FLAG_BOOL_NOT_HAS] = func(p, r): return _exec_flag_req_bool(p, r, false)
	rd[FUNC_FLAG_STR_IS] = func(p, r): return _exec_flag_req_str(p, r, REQ_OPERATOR.COMPARE.EQUAL)
	rd[FUNC_FLAG_STR_NOT] = func(p, r): return _exec_flag_req_str(p, r, REQ_OPERATOR.COMPARE.NOT_EQUAL)
	rd[FUNC_FLAG_INT_GT] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.GREATER_THAN)
	rd[FUNC_FLAG_INT_LT] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.LESS_THAN)
	rd[FUNC_FLAG_INT_EQ] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.EQUAL)
	rd[FUNC_FLAG_INT_NE] = func(p, r): return _exec_flag_req_int(p, r, REQ_OPERATOR.COMPARE.NOT_EQUAL)
	rd[FUNC_POEM_HAS] = func(p, r): return _exec_poem_req(p, r)
	
	# ── Consequence Operators ──
	var cd = _consequence_dispatch
	cd[FUNC_PROP_ADD] = func(p, r): return _exec_prop_op_add(p, r)
	cd[FUNC_PROP_SUB] = func(p, r): return _exec_prop_op_sub(p, r)
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
	cd[FUNC_FLAG_INT_REDUCE_IF_ABOVE] = func(p, r): return _create_flag_operator_int_reduce_if_above(p, r)
	cd[FUNC_TEMP_FLAG_BOOL_SET] = func(p, r): return _create_temp_flag_operator_bool_set(p, r)
	cd[FUNC_TEMP_FLAG_STR_SET] = func(p, r): return _create_temp_flag_operator_str_set(p, r)
	cd[FUNC_TEMP_FLAG_STR_APPEND] = func(p, r): return _create_temp_flag_operator_str_append(p, r)
	cd[FUNC_TEMP_FLAG_INT_SET] = func(p, r): return _create_temp_flag_operator_int_set(p, r)
	cd[FUNC_TEMP_FLAG_INT_APPEND] = func(p, r): return _create_temp_flag_operator_int_append(p, r)
	cd[FUNC_TEMP_FLAG_INT_REDUCE_IF_ABOVE] = func(p, r): return _create_temp_flag_operator_int_reduce_if_above(p, r)
	cd[FUNC_TIME_ADD] = func(p, r): return _exec_time_add_op(p, r)
	cd[FUNC_SCAN_AND_PUSH] = func(p, r): return _exec_scan_and_push_op(p, r)
	cd[FUNC_PUSH_EVENT] = func(p, r): return _exec_push_event_op(p, r)
	cd[FUNC_CONTEXT_KEY_PUSH_EVENT] = func(p, r): return _exec_context_key_push_event_op(p, r)
	cd[FUNC_POP_EVENT] = func(p, r): return _exec_pop_event_op(p, r)
	cd[FUNC_PUSH_FOCUSED_CHAT] = func(p, r): return _exec_push_focused_chat_op(p, r)
	cd[FUNC_CLEAR_SCHEDULED_EVENTS] = func(p, r): return _exec_clear_scheduled_events_op(p, r)
	cd[FUNC_QUEUE_EVENT] = func(p, r): return _exec_queue_event_op(p, r)
	cd[FUNC_RANDOM] = func(p, r): return _exec_random_op(p, r)
	cd[FUNC_RANDOM_PICK] = func(p, r): return _exec_random_pick_op(p, r)
	cd[FUNC_CONDITIONAL_RANDOM] = func(p, r): return _exec_conditional_random_op(p, r)
	cd[FUNC_CONTEXT_FETCH] = func(p, r): return _exec_context_fetch_op(p, r)
	cd[FUNC_NPC_BATCH_CHECK] = func(p, r): return _exec_npc_batch_check_op(p, r)
	cd[FUNC_IMAGINARY_LEVEL_REWARD] = func(p, r): return _exec_imaginary_level_reward_op(p, r)
	cd[FUNC_IMAGERY_ADD] = func(p, r): return _exec_imagery_add_op(p, r)
	cd[FUNC_PLAY_TRANSITION] = func(p, r): return _exec_play_transition_op(p, r)
	cd[FUNC_LEVERAGE_ADD] = func(p, r): return _exec_leverage_add_op(p, r)
	cd[FUNC_INFO] = func(p, r): return _exec_info_op(p, r)
	# ── New Archetype Operators ──
	cd[FUNC_ALL_EMO_SUB] = func(p, r): return _exec_all_emo_sub_op(p, r)
	cd[FUNC_ADD_SOCIAL_CREDIT] = func(p, r): return _exec_add_social_credit_op(p, r)
	# ── Image Operators ──
	cd[FUNC_IMAGE_PRESENT] = func(p, r): return _exec_image_present_op(p, r)
	cd[FUNC_IMAGE_SLIDE] = func(p, r): return _exec_image_slide_op(p, r)
	cd[FUNC_IMAGE_SHATTER] = func(p, r): return _exec_image_shatter_op(p, r)
	cd[FUNC_IMAGE_FADE_OUT] = func(p, r): return _exec_image_fade_out_op(p, r)
	cd[FUNC_IMAGE_REMOVE] = func(p, r): return _exec_image_remove_op(p, r)
	# ── Overlay Animation Operator ──
	cd[FUNC_OVERLAY_ANIM] = func(p, r): return _exec_overlay_anim_op(p, r)

# ──────────────────────────────────────────────
# Tags
# ──────────────────────────────────────────────

# 解析触发标签格式：domain:subcategory:category:specific_attribute (4段)
# 输入为单个 4 段式标签，split('/') 为兼容 Layer 2 分隔符
static func parse_tags(data: String) -> Array[String]:
	var tags = data.split('/')
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
# 新语法: prop_add(name="money"; val=100)|trait_add(name="corrupt")
static func parse_consequence_operators(data: String) -> Array[BaseOperator]:
	var operators: Array[BaseOperator] = []
	
	if data.is_empty():
		return operators
	
	var expressions = NamedDSLParser.split_expressions(data)
	for expr in expressions:
		# 🎯 use_template(urn=event_option:xxx) — 内联展开模板的 operators
		if expr.begins_with("use_template("):
			var template_ops = _expand_use_template(expr)
			if template_ops.size() > 0:
				operators.append_array(template_ops)
			continue
		
		var op = parse_operator(expr)
		if op:
			operators.append(op)
	
	return operators


# ── use_template DSL 展开 ──
# 语法: use_template(urn=event_option:xxx)
# 行为: 加载 URN 对应的 EventOption.tres，取其 choice_result.operators，
#       深度复制（duplicate）每个 operator 后内联追加到当前 operators 数组。
static func _expand_use_template(expr: String) -> Array[BaseOperator]:
	var result_ops: Array[BaseOperator] = []
	var parsed = NamedDSLParser.parse_single(expr)
	if parsed == null:
		Logging.err("use_template 解析失败: %s" % expr)
		return result_ops
	
	var urn = NamedDSLParser.get_str_param(parsed, "urn")
	if urn.is_empty():
		Logging.err("use_template 缺少 urn 参数: %s" % expr)
		return result_ops
	
	# 补全 URN 前缀
	if not urn.begins_with("urn:"):
		urn = "urn:" + urn
	
	var template = URN.get_resource_through_urn(urn)
	if template == null:
		Logging.err("use_template: 无法加载资源 %s (from: %s)" % [urn, expr])
		return result_ops
	
	if not template is EventOption:
		Logging.err("use_template: %s 不是 EventOption 类型，实际类型: %s" % [urn, typeof(template)])
		return result_ops
	
	for op in template.choice_result.operators:
		if op:
			# 深度复制，避免多个展开共享同一份 Operator 实例
			result_ops.append(op.duplicate(true))
		else:
			Logging.warn("use_template: %s 中存在 null operator" % urn)
	
	return result_ops

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

# Emotion Requirement（emo_gt / emo_lt）
static func _exec_emo_req(parsed: NamedDSLParser.ParseResult, raw: String, compare_op: REQ_OPERATOR.COMPARE) -> EmotionRequirement:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	
	if name.is_empty():
		Logging.err("情绪需求缺少 name 参数: %s" % raw)
		return null
	
	return _create_emotion_requirement(name, val, compare_op)

# Trait Requirement（共享 trait_has / trait_not_has）
static func _exec_trait_req(parsed: NamedDSLParser.ParseResult, raw: String, should_have: bool) -> BaseRequirements:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("特性需求缺少 name 参数: %s" % raw)
		return null
	
	var req = _create_trait_has_requirement(name, should_have)
	# 提取可选的 failed_hint 参数（由插件动态生成，通过模板替换注入）
	var fh = NamedDSLParser.get_str_param(parsed, "failed_hint", "")
	if not fh.is_empty():
		req.failed_hint = fh
	return req

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

# Property Operator: add — 强制正数（val ≥ 0），若为负则自动翻转
static func _exec_prop_op_add(parsed: NamedDSLParser.ParseResult, raw: String) -> PropertyOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("prop_add 缺少 name 参数: %s" % raw)
		return null
	if val < 0:
		Logging.warn("prop_add 的值应为正数，收到负数 %d，已自动纠正: %s" % [val, raw])
		val = -val
	return _create_property_operator(name, val)

# Property Operator: sub — 强制负数（val ≤ 0），若为正则自动翻转
static func _exec_prop_op_sub(parsed: NamedDSLParser.ParseResult, raw: String) -> PropertyOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if name.is_empty():
		Logging.err("prop_sub 缺少 name 参数: %s" % raw)
		return null
	if val > 0:
		Logging.warn("prop_sub 的值应为负数，收到正数 %d，已自动纠正: %s" % [val, raw])
		val = -val
	return _create_property_operator(name, val)

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

# Time Operator: add（追加时间消耗）
static func _exec_time_add_op(parsed: NamedDSLParser.ParseResult, raw: String) -> TimeOperator:
	var day = NamedDSLParser.get_int_param(parsed, "day")
	if day <= 0:
		Logging.warn("time_add 的 day 应为正数，收到 %d: %s" % [day, raw])
		day = max(1, day)
	var op = TimeOperator.new()
	op.day = float(day)
	return op

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

static func _create_flag_operator_int_reduce_if_above(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = FlagOperator.new()
	op.type = "int"
	op.operation = "reduce_if_above"
	op.threshold = NamedDSLParser.get_int_param(parsed, "threshold", 0)
	op.amount = NamedDSLParser.get_int_param(parsed, "amount", 0)

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op

# ──────────────────────────────────────────────
# Temp flag operator 辅助创建方法
# 与 flag_* 对应，但返回 TempFlagOperator 而非 FlagOperator
# ──────────────────────────────────────────────

static func _create_temp_flag_operator_bool_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "bool"
	op.operation = "set"
	op.value = NamedDSLParser.get_bool_param(parsed, "val", true)

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op


static func _create_temp_flag_operator_str_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "str"
	op.operation = "set"
	op.value = NamedDSLParser.get_str_param(parsed, "val")

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op


static func _create_temp_flag_operator_str_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "str"
	op.operation = "append"
	op.value = NamedDSLParser.get_str_param(parsed, "val")

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op


static func _create_temp_flag_operator_int_set(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "int"
	op.operation = "set"
	op.value = NamedDSLParser.get_int_param(parsed, "val")

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op


static func _create_temp_flag_operator_int_append(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "int"
	op.operation = "append"
	op.value = NamedDSLParser.get_int_param(parsed, "val")

	if not _resolve_flag_name(parsed, op, data):
		return null

	return op


static func _create_temp_flag_operator_int_reduce_if_above(parsed: NamedDSLParser.ParseResult, data: String) -> BaseOperator:
	var op = TempFlagOperator.new()
	op.type = "int"
	op.operation = "reduce_if_above"
	op.threshold = NamedDSLParser.get_int_param(parsed, "threshold", 0)
	op.amount = NamedDSLParser.get_int_param(parsed, "amount", 0)

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

static func _create_emotion_requirement(emotion_name: String, value: int, operator: REQ_OPERATOR.COMPARE) -> EmotionRequirement:
	var req = EmotionRequirement.new()
	req.volatile_stat = emotion_name
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


# ─── scan_and_push ────────────────────────────────────────────

static func _exec_scan_and_push_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ScanAndPushOperator:
	var op = ScanAndPushOperator.new()

	# tags: PackedStringArray — 必需参数
	var tags_val = parsed.params.get("tags")
	if tags_val is PackedStringArray:
		op.tags = tags_val
	elif tags_val is Array:
		# 兼容非类型化 Array → PackedStringArray
		var psa = PackedStringArray()
		for v in tags_val:
			psa.append(str(v))
		op.tags = psa
	else:
		Logging.err("scan_and_push 缺少 tags 参数或格式错误 (期望 PackedStringArray): %s" % raw)
		return null

	# weight_mult: float — 可选，默认 10.0
	var wm = parsed.params.get("weight_mult", 10.0)
	if wm is float or wm is int:
		op.weight_multiplier = float(wm)

	# fallback: String — 可选
	op.fallback_event = NamedDSLParser.get_str_param(parsed, "fallback")

	Logging.info("scan_and_push 解析成功: tags=%s, weight_mult=%.1f, fallback=%s" % [str(op.tags), op.weight_multiplier, op.fallback_event])
	return op


# ─── context_key_push_event ──────────────────────────────

static func _exec_context_key_push_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ContextKeyPushEventOperator:
	var args = parsed.args
	if not args.has("context_key"):
		Logging.err("context_key_push_event 缺少 context_key 参数: %s" % raw)
		return null
	var op = ContextKeyPushEventOperator.new()
	op.context_key = str(args["context_key"])
	return op


# ─── push_event / pop_event ─────────────────────────────────

static func _exec_push_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> PushEventOperator:
	var key = NamedDSLParser.get_str_param(parsed, "event_key")
	if key.is_empty():
		Logging.err("push_event 缺少 event_key 参数: %s" % raw)
		return null
	var op = PushEventOperator.new()
	op.event_key = key
	return op


static func _exec_pop_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> PopEventOperator:
	# DSL 语法: pop_event() 或 pop_event(text="你回过神来，发现自己还在书局里。")
	# text 参数可选，作为回归过渡文本传递给 NarrativeOverlay
	var transition_text = NamedDSLParser.get_str_param(parsed, "text", "")
	var op = PopEventOperator.new()
	op.transition_text = transition_text
	if not transition_text.is_empty():
		Logging.info("pop_event operator 创建成功: transition_text='%s'" % transition_text)
	return op


static func _exec_clear_scheduled_events_op(_parsed: NamedDSLParser.ParseResult, raw: String) -> ClearScheduledEvents:
	return ClearScheduledEvents.new()



# ─── push_focused_chat ──────────────────────────────────────────

static func _exec_push_focused_chat_op(parsed: NamedDSLParser.ParseResult, raw: String) -> PushFocusedChatOperator:
	var uuid = NamedDSLParser.get_str_param(parsed, "chat_uuid")
	if uuid.is_empty():
		Logging.err("push_focused_chat 缺少 chat_uuid 参数: %s" % raw)
		return null
	var op = PushFocusedChatOperator.new()
	op.chat_uuid = uuid
	return op


# ─── queue_event ──────────────────────────────────────────────

static func _exec_queue_event_op(parsed: NamedDSLParser.ParseResult, raw: String) -> QueueEventOperator:
	var key = NamedDSLParser.get_str_param(parsed, "event_key")
	if key.is_empty():
		Logging.err("queue_event 缺少 event_key 参数: %s" % raw)
		return null
	var op = QueueEventOperator.new()
	op.event_key = key
	return op


# ─── random ──────────────────────────────────────────────────────

# DSL 语法: random(val=80, success=prop_add(name="money", val=100), fail=prop_add(name="reputation", val=-5), success_hint="成功", failed_hint="失败")
# 解析为 RandomOperator，success/fail 参数是子 operator 表达式，需要递归解析
static func _exec_random_op(parsed: NamedDSLParser.ParseResult, raw: String) -> RandomOperator:
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if val < 0 or val > 100:
		Logging.warn("random: val 参数建议在 0-100 范围内，当前值: %d (raw: %s)" % [val, raw])
	
	var op = RandomOperator.new()
	op.random_value = clampi(val, 0, 100)
	
	# 解析 success 子 operator
	var success_str = NamedDSLParser.get_str_param(parsed, "success")
	if success_str.is_empty():
		Logging.warn("random: 缺少 success 参数，概率分支将无操作 (raw: %s)" % raw)
	else:
		var success_op = parse_operator(success_str)
		if success_op:
			op.success_operator = success_op
		else:
			Logging.warn("random: success 子 operator 解析失败: '%s'" % success_str)
	
	# 解析 fail 子 operator（可选）
	var fail_str = NamedDSLParser.get_str_param(parsed, "fail")
	if not fail_str.is_empty():
		var fail_op = parse_operator(fail_str)
		if fail_op:
			op.fail_operator = fail_op
		else:
			Logging.warn("random: fail 子 operator 解析失败: '%s'" % fail_str)
	
	# 可选的 hint 参数
	op.success_hint = NamedDSLParser.get_str_param(parsed, "success_hint")
	op.failed_hint = NamedDSLParser.get_str_param(parsed, "failed_hint")
	
	Logging.info("random operator 解析成功: val=%d, success=%s, fail=%s" % [val, success_str, fail_str])
	return op


# ─── random_pick ─────────────────────────────────────────────────

# DSL 语法: random_pick(datasource_name="feihualing_imageries", prop_from_result="name", key_stored_context="feihualing_words", select_count=4)
# 解析为 RandomPickOperator，随机从 Database 的数据源中选取 N 个条目
static func _exec_random_pick_op(parsed: NamedDSLParser.ParseResult, raw: String) -> RandomPickOperator:
	var datasource_name = NamedDSLParser.get_str_param(parsed, "datasource_name")
	if datasource_name.is_empty():
		Logging.err("random_pick: 缺少 datasource_name 参数: %s" % raw)
		return null

	var key_stored_context = NamedDSLParser.get_str_param(parsed, "key_stored_context")
	if key_stored_context.is_empty():
		Logging.err("random_pick: 缺少 key_stored_context 参数: %s" % raw)
		return null

	var op = RandomPickOperator.new()
	op.datasource_name = datasource_name
	op.prop_from_result = NamedDSLParser.get_str_param(parsed, "prop_from_result")
	op.key_stored_context = key_stored_context
	op.select_count = NamedDSLParser.get_int_param(parsed, "select_count", 4)

	Logging.info("random_pick operator 解析成功: datasource=%s, prop=%s, key=%s, count=%d" % [
		op.datasource_name, op.prop_from_result, op.key_stored_context, op.select_count])
	return op


# ─── conditional_random ───────────────────────────────────────────

# DSL 语法: conditional_random(base=80, modifiers=[trait_key/delta/label], success=prop_add(name="money", val=100), fail=prop_add(name="reputation", val=-5), success_hint="成功", failed_hint="失败")
# 解析为 ConditionalRandomOperator，modifiers 使用 / 分隔元素，每个元素格式为 trait_key/delta/label
static func _exec_conditional_random_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ConditionalRandomOperator:
	var base = NamedDSLParser.get_int_param(parsed, "base", 50)
	var op = ConditionalRandomOperator.new()
	op.base_chance = clampi(base, 0, 99)

	# 解析 modifiers 数组
	# DSL 中写法: modifiers=[kuangda_kuangke/20/狂客修正/...]
	var raw_modifiers = parsed.params.get("modifiers", null)
	if raw_modifiers != null:
		if raw_modifiers is Array:
			for entry in raw_modifiers:
				var entry_str: String = str(entry)
				var parts = entry_str.split("/")
				var modifier = ChanceModifier.new()
				if parts.size() >= 1:
					modifier.trait_key = parts[0].strip_edges()
				if parts.size() >= 2:
					modifier.delta = int(parts[1].strip_edges())
				if parts.size() >= 3:
					modifier.label = parts[2].strip_edges()
				op.modifiers.append(modifier)
				Logging.info("conditional_random: modifier parsed trait_key=%s delta=%d label=%s" % [modifier.trait_key, modifier.delta, modifier.label])
		else:
			Logging.warn("conditional_random: modifiers 不是数组类型: %s (raw: %s)" % [str(raw_modifiers), raw])

	# 解析 success 子 operators（| 分隔的多个 operator 表达式）
	var success_str = NamedDSLParser.get_str_param(parsed, "success")
	if not success_str.is_empty():
		var success_ops = parse_consequence_operators(success_str)
		op.success_result = success_ops
	else:
		Logging.warn("conditional_random: 缺少 success 参数 (raw: %s)" % raw)

	# 解析 fail 子 operators（可选，| 分隔的多个 operator 表达式）
	var fail_str = NamedDSLParser.get_str_param(parsed, "fail")
	if not fail_str.is_empty():
		var fail_ops = parse_consequence_operators(fail_str)
		op.fail_result = fail_ops

	# 可选的 hint 参数
	op.success_hint = NamedDSLParser.get_str_param(parsed, "success_hint")
	op.failed_hint = NamedDSLParser.get_str_param(parsed, "failed_hint")

	Logging.info("conditional_random operator 解析成功: base=%d, modifiers=%d, success=%d ops, fail=%d ops" % [
		op.base_chance, op.modifiers.size(), op.success_result.size(), op.fail_result.size()])
	return op


# ─── context_fetch ──────────────────────────────────────────────

# DSL 语法: context_fetch(fetched_key="feihualing_chosen_word", datasource_name="imaginaries", prop_from_result="name", key_stored_context="chosen_word_display")
# 解析为 ContextFetchOperators，从 Database 的数据源中用 context key 的值查数据
static func _exec_context_fetch_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ContextFetchOperators:
	var fetched_key = NamedDSLParser.get_str_param(parsed, "fetched_key")
	if fetched_key.is_empty():
		Logging.err("context_fetch: 缺少 fetched_key 参数: %s" % raw)
		return null

	var datasource_name = NamedDSLParser.get_str_param(parsed, "datasource_name")
	if datasource_name.is_empty():
		Logging.err("context_fetch: 缺少 datasource_name 参数: %s" % raw)
		return null

	var key_stored_context = NamedDSLParser.get_str_param(parsed, "key_stored_context")
	if key_stored_context.is_empty():
		Logging.err("context_fetch: 缺少 key_stored_context 参数: %s" % raw)
		return null

	var op = ContextFetchOperators.new()
	op.fetched_key = fetched_key
	op.datasource_name = datasource_name
	op.prop_from_result = NamedDSLParser.get_str_param(parsed, "prop_from_result")
	op.key_stored_context = key_stored_context
	op.urn_prefix = NamedDSLParser.get_str_param(parsed, "urn_prefix")

	Logging.info("context_fetch operator 解析成功: fetched=%s, ds=%s, prop=%s, store=%s, urn=%s" % [
		op.fetched_key, op.datasource_name, op.prop_from_result, op.key_stored_context, op.urn_prefix])
	return op


# ─── npc_batch_check ───────────────────────────────────────────

# DSL 语法: npc_batch_check(participants_key="guests", target_context_key="npc_report", check_prop="TALENT", text_template="FEIHUALING")
# 解析为 NpcBatchCheckOperator，批量检定 NPC + 生成战报
static func _exec_npc_batch_check_op(parsed: NamedDSLParser.ParseResult, raw: String) -> NpcBatchCheckOperator:
	var participants_key = NamedDSLParser.get_str_param(parsed, "participants_key")
	if participants_key.is_empty():
		Logging.err("npc_batch_check: 缺少 participants_key 参数: %s" % raw)
		return null

	var target_context_key = NamedDSLParser.get_str_param(parsed, "target_context_key")
	if target_context_key.is_empty():
		Logging.err("npc_batch_check: 缺少 target_context_key 参数: %s" % raw)
		return null

	var check_prop = NamedDSLParser.get_str_param(parsed, "check_prop")
	if check_prop.is_empty():
		Logging.err("npc_batch_check: 缺少 check_prop 参数: %s" % raw)
		return null

	var text_template = NamedDSLParser.get_str_param(parsed, "text_template")
	if text_template.is_empty():
		Logging.err("npc_batch_check: 缺少 text_template 参数: %s" % raw)
		return null

	var op = NpcBatchCheckOperator.new()
	op.participants_key = participants_key
	op.target_context_key = target_context_key
	op.check_prop = check_prop
	op.text_template = text_template

	Logging.info("npc_batch_check operator 解析成功: participants=%s, target=%s, prop=%s, template=%s" % [
		op.participants_key, op.target_context_key, op.check_prop, op.text_template])
	return op


# ─── poem_has ────────────────────────────────────────────────────

# DSL 语法: poem_has(type=[GAN_YE/YING_ZHI] ; min_level=2)
# 返回 PoemRequirement（检查玩家是否拥有符合条件的诗词 trait）
static func _exec_poem_req(parsed: NamedDSLParser.ParseResult, raw: String) -> PoemRequirement:
	var req = PoemRequirement.new()

	# 解析 type 参数（数组格式 [GAN_YE/YING_ZHI] → PackedStringArray）
	if parsed.params.has("type"):
		var type_val = parsed.params["type"]
		if type_val is PackedStringArray:
			for type_str in type_val:
				for i in ENUMS.POEM_TYPE.size():
					if ENUMS.POEM_TYPE.keys()[i] == type_str:
						req.accepted_poem_types.append(i)
						break
		elif type_val is String and not (type_val as String).is_empty():
			# 单个类型回退，如 type=GAN_YE
			var single_type = type_val as String
			for i in ENUMS.POEM_TYPE.size():
				if ENUMS.POEM_TYPE.keys()[i] == single_type:
					req.accepted_poem_types.append(i)
					break

	# 解析 min_level 参数

	# 解析可选的 failed_hint 参数（由插件动态生成，通过模板替换注入）
	# 格式: poem_has(type=GAN_YE; min_level=1; failed_hint="去写首干谒诗再来")
	var fh = NamedDSLParser.get_str_param(parsed, "failed_hint", "")
	if not fh.is_empty():
		req.failed_hint = fh

	return req


# ─── imaginary_level_reward ──────────────────────────────────────

# DSL 语法: imaginary_level_reward(l3_fame=50, l2_fame=20, l1_fame=0)
# 返回 ImaginaryLevelRewardOperator（弹出 picker 让玩家选意象，按等级给名声）
static func _exec_imaginary_level_reward_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImaginaryLevelRewardOperator:
	var l3_fame = NamedDSLParser.get_int_param(parsed, "l3_fame", 50)
	var l2_fame = NamedDSLParser.get_int_param(parsed, "l2_fame", 20)
	var l1_fame = NamedDSLParser.get_int_param(parsed, "l1_fame", 0)

	var op = ImaginaryLevelRewardOperator.new()
	op.l3_fame = l3_fame
	op.l2_fame = l2_fame
	op.l1_fame = l1_fame

	Logging.info("imaginary_level_reward operator 创建成功: l3_fame=%d, l2_fame=%d, l1_fame=%d" % [l3_fame, l2_fame, l1_fame])
	return op


# ─── imagery_add ────────────────────────────────────────────────

# DSL 语法: imagery_add(name=ENV_POLITICS_CLOUD_LEYOU)
# 返回 ImageryAcquisitionOperator（广播 EventBus.request_add_imaginary）
static func _exec_imagery_add_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImageryAcquisitionOperator:
	var name = NamedDSLParser.get_str_param(parsed, "name")
	if name.is_empty():
		Logging.err("imagery_add 缺少 name 参数: %s" % raw)
		return null
	var op = ImageryAcquisitionOperator.new()
	op.imagery_name = name
	Logging.info("imagery_add operator 创建成功: name=%s" % name)
	return op


# ─── play_transition ─────────────────────────────────────────

# DSL 语法: play_transition(texts=["天宝四年，秋。", "你带着半生积蓄，踏入长安。"])
# 解析为 PlayTransitionOperator，推入 Cinematic 到事件栈
static func _exec_play_transition_op(parsed: NamedDSLParser.ParseResult, raw: String) -> PlayTransitionOperator:
	var texts_val = parsed.params.get("texts")
	var texts: Array[String] = []

	if texts_val is PackedStringArray:
		for v in texts_val:
			texts.append(v)
	elif texts_val is Array:
		for v in texts_val:
			texts.append(str(v))
	else:
		var single = NamedDSLParser.get_str_param(parsed, "texts")
		if not single.is_empty():
			texts.append(single)

	if texts.is_empty():
		Logging.err("play_transition 缺少 texts 参数: %s" % raw)
		return null

	var op = PlayTransitionOperator.new()
	op.texts = texts
	Logging.info("play_transition operator 创建成功: %d 段文字" % texts.size())
	return op


# ─── image_present ─────────────────────────────────────────

# DSL 语法: image_present(id="juanzhou", pos="center")
# 解析为 ImagePresentOperator，按 ID 展示图片
static func _exec_image_present_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImagePresentOperator:
	var image_id = NamedDSLParser.get_str_param(parsed, "id")
	if image_id.is_empty():
		Logging.err("image_present 缺少 id 参数: %s" % raw)
		return null

	var pos = NamedDSLParser.get_str_param(parsed, "pos", "center")
	if pos.is_empty():
		pos = "center"

	var op = ImagePresentOperator.new()
	op.image_id = image_id
	op.position = pos
	Logging.info("image_present operator 创建成功: id=%s, pos=%s" % [image_id, pos])
	return op


# ─── image_slide ──────────────────────────────────────────

# DSL 语法: image_slide(id="juanzhou", pos="top_center", duration=1.5)
# 解析为 ImageSlideOperator，滑动已有图片到目标位置
static func _exec_image_slide_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImageSlideOperator:
	var image_id = NamedDSLParser.get_str_param(parsed, "id")
	if image_id.is_empty():
		Logging.err("image_slide 缺少 id 参数: %s" % raw)
		return null

	var pos = NamedDSLParser.get_str_param(parsed, "pos", "center")
	var duration_val = parsed.params.get("duration", 1.0)
	var duration = float(duration_val) if duration_val != null else 1.0

	var op = ImageSlideOperator.new()
	op.image_id = image_id
	op.target_position = pos
	op.duration = duration
	Logging.info("image_slide operator 创建成功: id=%s, pos=%s, duration=%.2f" % [image_id, pos, duration])
	return op


# ─── image_shatter ────────────────────────────────────────

# DSL 语法: image_shatter(id="juanzhou", duration=1.0)
# 解析为 ImageShatterOperator，粉碎已有图片
static func _exec_image_shatter_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImageShatterOperator:
	var image_id = NamedDSLParser.get_str_param(parsed, "id")
	if image_id.is_empty():
		Logging.err("image_shatter 缺少 id 参数: %s" % raw)
		return null

	var duration_val = parsed.params.get("duration", 1.0)
	var duration = float(duration_val)

	var op = ImageShatterOperator.new()
	op.image_id = image_id
	op.duration = duration
	Logging.info("image_shatter operator 创建成功: id=%s, duration=%.2f" % [image_id, duration])
	return op


# ─── image_fade_out ───────────────────────────────────────

# DSL 语法: image_fade_out(id="juanzhou", duration=2.0)
# 解析为 ImageFadeOutOperator，淡出已有图片
static func _exec_image_fade_out_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImageFadeOutOperator:
	var image_id = NamedDSLParser.get_str_param(parsed, "id")
	if image_id.is_empty():
		Logging.err("image_fade_out 缺少 id 参数: %s" % raw)
		return null

	var duration_val = parsed.params.get("duration", 1.0)
	var duration = float(duration_val)

	var op = ImageFadeOutOperator.new()
	op.image_id = image_id
	op.duration = duration
	Logging.info("image_fade_out operator 创建成功: id=%s, duration=%.2f" % [image_id, duration])
	return op


# ─── image_remove ─────────────────────────────────────────

# DSL 语法: image_remove(id="juanzhou")
# 解析为 ImageRemoveOperator，立即移除已有图片
static func _exec_image_remove_op(parsed: NamedDSLParser.ParseResult, raw: String) -> ImageRemoveOperator:
	var image_id = NamedDSLParser.get_str_param(parsed, "id")
	if image_id.is_empty():
		Logging.err("image_remove 缺少 id 参数: %s" % raw)
		return null

	var op = ImageRemoveOperator.new()
	op.image_id = image_id
	Logging.info("image_remove operator 创建成功: id=%s" % image_id)
	return op


# ─── leverage_add ─────────────────────────────────────────

# DSL 语法: leverage_add(target_tag="TARGET_IDENTITY_QUANGUI", key="quangui_corruption")
#           leverage_add(target_tag="TARGET_NPC_LIBAI", key="libai_secret", silent=true)
# 解析为 LeverageAddOperator，调用 RelationFlagManager.add_leverage()
static func _exec_leverage_add_op(parsed: NamedDSLParser.ParseResult, raw: String) -> LeverageAddOperator:
	var target_tag = NamedDSLParser.get_str_param(parsed, "target_tag")
	if target_tag.is_empty():
		Logging.err("leverage_add 缺少 target_tag 参数: %s" % raw)
		return null

	var key = NamedDSLParser.get_str_param(parsed, "key")
	if key.is_empty():
		Logging.err("leverage_add 缺少 key 参数: %s" % raw)
		return null

	var silent = NamedDSLParser.get_bool_param(parsed, "silent", false)

	var op = LeverageAddOperator.new()
	op.target_tag = target_tag
	op.leverage_key = key
	op.silent = silent
	Logging.info("leverage_add operator 创建成功: target_tag=%s, key=%s, silent=%s" % [target_tag, key, str(silent)])
	return op


# ─── info ─────────────────────────────────────────────────

# DSL 语法: info(msg="你注意到了一些可疑的事情")
# 解析为 InfoDemoOperator，发射 request_toast 通知
# ─── overlay_anim ──────────────────────────────────────────
# DSL 语法: overlay_anim(strategy="slide_out_and_back", duration=0.6)
# 解析为 OverlayAnimationOperator，驱动 NarrativeOverlay 执行动画
static func _exec_overlay_anim_op(parsed: NamedDSLParser.ParseResult, raw: String) -> OverlayAnimationOperator:
	var strategy: String = str(parsed.attrs.get("strategy", "slide_out_and_back"))
	if strategy.is_empty():
		strategy = "slide_out_and_back"
	var duration: float = float(parsed.attrs.get("duration", 0.5))
	var op = OverlayAnimationOperator.new()
	op.strategy = strategy
	op.duration = duration
	Logging.info("overlay_anim operator 创建成功: strategy=%s, duration=%.2f" % [strategy, duration])
	return op


static func _exec_info_op(parsed: NamedDSLParser.ParseResult, raw: String) -> InfoDemoOperator:
	var msg = NamedDSLParser.get_str_param(parsed, "msg")
	if msg.is_empty():
		Logging.err("info 缺少 msg 参数: %s" % raw)
		return null

	var op = InfoDemoOperator.new()
	op.info = msg
	Logging.info("info operator 创建成功: msg=%s" % msg)
	return op


# ─── all_emo_sub ───────────────────────────────────────

# DSL 语法: all_emo_sub(val=m_emotion_loss)
# 对所有情绪执行 reduce_to_lowest_zero 操作，减去指定值。
# 解析为 AllEmoSubOperator
static func _exec_all_emo_sub_op(parsed: NamedDSLParser.ParseResult, raw: String) -> BaseOperator:
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if val == 0:
		Logging.err("all_emo_sub 缺少 val 参数: %s" % raw)
		return null

	var op := AllEmoSubOperator.new()
	op.value = val
	Logging.info("all_emo_sub operator 创建成功: val=%d" % val)
	return op


# ─── add_social_credit ─────────────────────────────────

# DSL 语法: add_social_credit(val=10)
# 社交系统暂未实装，直接警告并跳过（不创建代理 operator）。
# 等社交系统上线后再实现真实逻辑。
static func _exec_add_social_credit_op(parsed: NamedDSLParser.ParseResult, raw: String) -> BaseOperator:
	var val = NamedDSLParser.get_int_param(parsed, "val")
	if val == 0:
		Logging.err("add_social_credit 缺少 val 参数: %s" % raw)
		return null

	Logging.warn("add_social_credit: 社交系统未实装，跳过此操作 (%s)" % raw)
	return null
