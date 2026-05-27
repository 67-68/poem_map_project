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
	var flag = Database.flags.get(flag_id)
	if not flag:
		Logging.err('Flag %s not found in Database.flags' % flag_id)
		return

	match type:
		'str':
			if operation == 'set':
				flag.set_to(str(value))
			elif operation == 'append':
				flag.val_str += str(value)
		'int':
			if operation == 'set':
				flag.set_to(int(value))
			elif operation == 'append':
				flag.append(int(value))
		'bool':
			if operation == 'set':
				var bool_str = str(value).to_lower()
				# 支持多种布尔值表示：true/false, t/f, 1/0, yes/no, TRUE/FALSE
				var bool_val = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
				flag.set_to(bool_val)
			elif operation == 'append':
				Logging.warn('Append operation not supported for bool flags')
		_:
			Logging.err('Unknown flag type: %s for flag %s' % [type, flag_id])
