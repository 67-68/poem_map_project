
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
		'append'
) var operation := 'set'
@export var target_flag_id_from_context: String = ''

func init(_context: Dictionary) -> Dictionary:
	var flag_uid = _context.get(target_flag_id_from_context)
	if flag_uid: flag_id = flag_uid
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
