@tool
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
@export_enum(
	'extra_large','large', 'medium', 'small'
) var ranked_value: String = ""
@export var rank_negative: bool = false

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

	# ranked_value → named_amounts (优先级高于 value, 完全忽略 value 原值)
	if not ranked_value.is_empty():
		var amounts = NamedDSLParser._load_named_amounts()
		var prefix := ""
		match ranked_value:
			"small":
				prefix = "s_"
			"medium":
				prefix = "m_"
			"large":
				prefix = "l_"
			"extra_large":
				prefix = "xl_"
			_:
				Logging.err("PropertyOperator.init: unknown ranked_value: " + ranked_value)
		if not prefix.is_empty():
			var prop_lower := property.to_lower()
			var found := false
			for key in amounts:
				if key.begins_with(prefix) and prop_lower in key:
					var entry_val = amounts[key]
					if not rank_negative and entry_val > 0:
						value = entry_val
						found = true
						Logging.debug("PropertyOperator.init: ranked_value resolved " + ranked_value + " -> " + key + " = " + str(value))
						break
					elif rank_negative and entry_val < 0:
						value = entry_val
						found = true
						Logging.debug("PropertyOperator.init: ranked_value resolved " + ranked_value + " -> " + key + " = " + str(value))
						break
			if not found:
				Logging.err("PropertyOperator.init: no matching named_amount for ranked_value=" + ranked_value + ", property=" + prop_lower + ", negative=" + str(rank_negative))

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
	Logging.debug("PropertyOperator.operate: property=" + property + ", value=" + str(value) + ", _is_repeated_action=" + str(PlayerState._is_repeated_action))
	
	# 🆕 重复行动疲惫：对属性变动施加 20% 惩罚
	# 正收益（val>0）*0.8 = 减少 20% 获得
	# 负消耗（val<0）*1.2 = 增加 20% 消耗
	var adjusted_value: int = value
	if PlayerState._is_repeated_action and value != 0:
		if value > 0:
			adjusted_value = int(float(value) * 0.8)
		else:
			adjusted_value = int(float(value) * 1.2)
		Logging.info("PropertyOperator.operate: 重复行动惩罚 applied, %d → %d (×%.1f)" % [value, adjusted_value, (0.8 if value > 0 else 1.2)])
	PlayerState.append_stat(property, adjusted_value)
	# 触发属性变化音效（AudioManager 统一管理 0.4s 防重叠间隔）
	AudioManager.play_property_sound(property, adjusted_value)
	_emit_float_text(adjusted_value)

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
	var display_value: int = value
	
	# 🆕 重复行动疲惫：预览文本展示调整后数值
	if PlayerState._is_repeated_action:
		if value > 0:
			display_value = int(float(value) * 0.8)
		else:
			display_value = int(float(value) * 1.2)
	
	var perception_text = prop.get_change_perception_text(value)
	var base_str: String
	
	if PlayerState._is_repeated_action and display_value != value:
		if perception_text.is_empty():
			base_str = "%s %s：%+d（原%+d，重复行动%s%d%%）" % [cn_name, arrows, display_value, value, ("+" if value < 0 else "-"), 20]
		else:
			base_str = "%s %s：%+d（原%+d%s，重复行动%s%d%%）" % [cn_name, arrows, display_value, value, "(%s)" % perception_text, ("+" if value < 0 else "-"), 20]
		Logging.info("PropertyOperator.describe_preview: 重复行动 preview, %+d→%+d for '%s'" % [value, display_value, property])
	else:
		if perception_text.is_empty():
			base_str = "%s %s：%+d" % [cn_name, arrows, value]
		else:
			base_str = "%s %s：%+d(%s)" % [cn_name, arrows, value, perception_text]
	
	return base_str

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
