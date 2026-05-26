class_name FlagRequirement extends BaseRequirements
# 用来判断某个 flag 是否达到要求

@export var flag_id: String = ""
@export_enum(
	'str',
	'int',
	'bool'
) var type := ''
@export var value: Variant
@export var operator: REQ_OPERATOR.COMPARE = REQ_OPERATOR.COMPARE.GREATER_THAN
@export var failed_hint: String

func get_referenced_flags() -> Array[String]:
	if flag_id.is_empty():
		return []
	return [flag_id]

func compare(_player_state: PlayerState) -> bool:
	var flag = Database.flags.get(flag_id)
	if not flag:
		Logging.err('Flag %s not found in Database.flags' % flag_id)
		return false
	
	match type:
		'str':
			var current_val = flag.val_str
			var target_val = str(value)
			if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
				return current_val < target_val
			else:
				return current_val > target_val
		'int':
			var current_val = flag.val_int
			var target_val = int(value)
			if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
				return current_val < target_val
			else:
				return current_val > target_val
		'bool':
			var current_val = flag.val_bool
			var bool_str = str(value).to_lower()
			var target_val = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
			if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
				return current_val < target_val
			else:
				return current_val > target_val
		_:
			Logging.err('Unknown flag type: %s for flag %s' % [type, flag_id])
			return false
