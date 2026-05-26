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
				flag.set_to(bool(value))
			elif operation == 'append':
				Logging.warn('Append operation not supported for bool flags')
		_:
			Logging.err('Unknown flag type: %s for flag %s' % [type, flag_id])
