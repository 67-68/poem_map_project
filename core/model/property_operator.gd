class_name PropertyOperator extends BaseOperator

@export var _property: ENUMS.PROPS = -1
var property := '':
	get():
		if str_props:
			return str_props
		Logging.warn("PropertyOperator: string property not set, use enum property")
		return ENUMS.to_prop_str(_property)
	set(value):
		str_props = value
@export var str_props: String = ""
@export var value: int = 0
@export var context_key_for_multiplication: String = "property_multiplication"

func init(_context: Dictionary) -> Dictionary:
	# dynamic parse str_props -> _property enum
	if not str_props.is_empty():
		var found := false
		for i in ENUMS.PROPS.size():
			if ENUMS.PROPS.keys()[i].to_lower() == str_props.to_lower():
				_property = i
				found = true
				break
		if not found:
			Logging.warn("PropertyOperator.init: str_props cannot resolve to PROPS enum: " + str_props)

	if _context.has(context_key_for_multiplication):
		var ctx_val = _context[context_key_for_multiplication]
		if typeof(ctx_val) in [TYPE_FLOAT, TYPE_INT]:
			var original_value = value
			value = int(float(value) * float(ctx_val))
			Logging.debug("PropertyOperator: Multiplying value " + str(original_value) + " by context[" + context_key_for_multiplication + "]=" + str(float(ctx_val)) + " -> " + str(value))
		else:
			Logging.warn("PropertyOperator: context[" + context_key_for_multiplication + "] has unexpected type " + str(typeof(ctx_val)) + ", skipping multiplication")
	else:
		Logging.debug("PropertyOperator: context key not found, no multiplication applied: " + context_key_for_multiplication)
	return _context

func operate():
	Logging.debug("PropertyOperator.operate: property=" + property + ", value=" + str(value))
	PlayerState.append_stat(property, value)
	# 触发属性变化音效（AudioManager 统一管理 0.4s 防重叠间隔）
	AudioManager.play_property_sound(property, value)
	_emit_float_text(value)

func _emit_float_text(delta: int) -> void:
	Logging.debug("PropertyOperator._emit_float_text: property=" + property + ", delta=" + str(delta))
	if delta == 0:
		Logging.debug("PropertyOperator._emit_float_text: delta=0, skip")
		return
	var prop = Database.get_property(property)
	if not prop:
		Logging.err("PropertyOperator._emit_float_text: property not found in Database: " + property)
		return
	var perception_text = prop.get_change_perception_text(delta)
	Logging.debug("PropertyOperator._emit_float_text: get_change_perception_text -> " + str(perception_text))
	if perception_text.is_empty():
		Logging.debug("PropertyOperator._emit_float_text: perception_text is empty, skip")
		return
	Logging.debug("PropertyOperator._emit_float_text: emitting request_float_text")
	EventBus.request_float_text.emit(perception_text)

func describe_preview() -> String:
	if value == 0 or property.is_empty():
		return ""
	var prop = Database.get_property(property)
	if not prop:
		return ""
	var cn_name = prop.get_display_name() if not prop.name.is_empty() else property
	var arrow_char = "↑" if value > 0 else "↓"
	var arrow_count = _get_arrow_count(property, value)
	var arrows = ""
	for i in arrow_count:
		arrows += arrow_char
	var perception_text = prop.get_change_perception_text(value)
	if perception_text.is_empty():
		return cn_name + " " + arrows
	return cn_name + " " + arrows + "：" + perception_text

static func _get_arrow_count(prop_name: String, delta: int) -> int:
	var amounts = NamedDSLParser._load_named_amounts()
	if amounts.is_empty():
		return 1
	var abs_val = abs(delta)
	var is_positive = delta > 0
	var prop_lower = prop_name.to_lower()
	var candidates: Array[Dictionary] = []
	for key in amounts:
		var entry_val = amounts[key]
		if (is_positive and entry_val > 0) or (not is_positive and entry_val < 0):
			if key.contains(prop_lower):
				candidates.append({"key": key, "abs": abs(entry_val)})
	if candidates.is_empty():
		return 1
	var best_abs = candidates[0]["abs"]
	var best_key = candidates[0]["key"]
	var min_diff = abs(abs_val - best_abs)
	for c in candidates:
		var diff = abs(abs_val - c["abs"])
		if diff < min_diff:
			min_diff = diff
			best_abs = c["abs"]
			best_key = c["key"]
	if best_key.begins_with("l_"):
		return 3
	elif best_key.begins_with("m_"):
		return 2
	else:
		return 1

# ================================================================
# convert_prop_limit_requirement
# ================================================================

func convert_prop_limit_requirement() -> PropertyRequirement:
	var prop = Database.get_property(property)
	if not prop:
		return null
	var current_val = PlayerState.get_stat_val(property)
	var new_val = current_val + value

	if value < 0:
		if new_val < prop.lowest:
			var req := PropertyRequirement.new()
			req.property = property
			req.value = prop.lowest - value
			req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
			req.failed_hint = "不足，当前" + str(current_val) + "，消耗后仅剩" + str(new_val)
			return req
	elif value > 0:
		if prop.hard_max >= 0 and new_val > prop.hard_max:
			var req := PropertyRequirement.new()
			req.property = property
			req.value = prop.hard_max - value + 1
			req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
			req.failed_hint = "已达上限，无法继续获得"
			return req
	return null

func get_referenced_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []

func get_demanded_flags() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
