
@tool
class_name FlagOperator extends BaseOperator

@export var flag_id: String = ""
@export_enum(
		'str',
		'int',
		'bool'
) var type := ''
@export var value: Variant
@export_enum(
		'set',
		'append',
		'reduce_if_above'
) var operation := 'set'
@export var threshold: int = 0
@export var amount: int = 0
@export var target_flag_id_from_context: String = ''
## flag_id 前缀：在 target_flag_id_from_context 解析后拼接到 flag_id 前面
## 例如 prefix="talked_to_" + resolved="libai" → flag_id="talked_to_libai"
@export var flag_id_prefix: String = ''

func init(_context: Dictionary) -> Dictionary:
	#breakpoint
	if target_flag_id_from_context.is_empty():
		Logging.warn('FlagOperator.init: target_flag_id_from_context is empty, flag_id remains "%s"' % flag_id)
		return _context

	var flag_uid = _context.get(target_flag_id_from_context)
	if flag_uid:
		flag_id = flag_id_prefix + str(flag_uid)
		Logging.debug('FlagOperator.init: resolved flag_id from context key "%s" -> "%s" (prefix="%s")' % [target_flag_id_from_context, flag_id, flag_id_prefix])
	else:
		Logging.warn('FlagOperator.init: context key "%s" not found in context, flag_id remains "%s"' % [target_flag_id_from_context, flag_id])
	return _context

func get_referenced_flags() -> Array:
	if flag_id.is_empty():
		return []
	return [flag_id]

func get_demanded_flags() -> Array:
	if flag_id.is_empty():
		return []
	return [flag_id]

func get_provided_flags() -> Array:
	if flag_id.is_empty():
		return []
	return [flag_id]

func operate():
	#breakpoint
	match type:
		'str':
			if operation == 'set':
				PlayerState.set_flag(flag_id, str(value), 'str')
			elif operation == 'append':
				var current_val = PlayerState.get_flag(flag_id)
				if current_val == null:
					current_val = ''
				PlayerState.set_flag(flag_id, str(current_val) + str(value), 'str')
		'int':
			if operation == 'set':
				PlayerState.set_flag(flag_id, int(value), 'int')
			elif operation == 'append':
				PlayerState.append_flag(flag_id, int(value))
			elif operation == 'reduce_if_above':
				var current = PlayerState.get_flag(flag_id)
				if current == null:
					Logging.warn('FlagOperator.reduce_if_above: flag "%s" is null, skipping' % flag_id)
					return
				var current_int = int(current)
				if current_int > threshold:
					var new_val = current_int - amount
					PlayerState.set_flag(flag_id, new_val, 'int')
					Logging.debug('FlagOperator.reduce_if_above: flag "%s" reduced from %d to %d (threshold=%d, amount=%d)' % [flag_id, current_int, new_val, threshold, amount])
				else:
					Logging.debug('FlagOperator.reduce_if_above: flag "%s" value %d <= threshold %d, no change' % [flag_id, current_int, threshold])
		'bool':
			if operation == 'set':
				var bool_str = str(value).to_lower()
				# 支持多种布尔值表示：true/false, t/f, 1/0, yes/no, TRUE/FALSE
				var bool_val = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
				PlayerState.set_flag(flag_id, bool_val, 'bool')
			elif operation == 'append':
				Logging.warn('Append operation not supported for bool flags')
		_:
			Logging.err('Unknown flag type: %s for flag %s' % [type, flag_id])
