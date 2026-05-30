@tool
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
## 动态 flag 名称：从 context 中取指定 key 的值作为 flag_id
## 与 FlagOperator.target_flag_id_from_context 行为一致
@export var target_flag_id_from_context: String = ""
## flag_id 前缀：在 target_flag_id_from_context 解析后拼接到 flag_id 前面
## 例如 prefix="talked_to_" + resolved="libai" → flag_id="talked_to_libai"
@export var flag_id_prefix: String = ""

func get_referenced_flags() -> Array:
	if flag_id.is_empty():
		return []
	return [flag_id]

func init(context: Dictionary) -> Dictionary:
	# 动态解析 flag_id：如果 target_flag_id_from_context 不为空，
	# 从 context 中取出对应的值作为运行时 flag_id
	if not target_flag_id_from_context.is_empty():
		var resolved = context.get(target_flag_id_from_context)
		if resolved != null:
			flag_id = flag_id_prefix + str(resolved)
			Logging.debug('FlagRequirement.init: resolved flag_id from context key "%s" -> "%s" (prefix="%s")' % [target_flag_id_from_context, flag_id, flag_id_prefix])
		else:
			Logging.warn('FlagRequirement.init: context key "%s" not found, flag_id remains "%s"' % [target_flag_id_from_context, flag_id])
	return context

func compare(_player_state: PlayerState) -> bool:
	if not PlayerState.has_flag(flag_id):
		Logging.debug('Flag %s not set in PlayerState, treating as zero/empty' % flag_id)

	match type:
		'str':
			var current_val = PlayerState.get_flag(flag_id)
			if current_val == null:
				current_val = ''
			var target_val = str(value)
			match operator:
				REQ_OPERATOR.COMPARE.LESS_THAN:
					return str(current_val) < target_val
				REQ_OPERATOR.COMPARE.GREATER_THAN:
					return str(current_val) > target_val
				REQ_OPERATOR.COMPARE.EQUAL:
					return str(current_val) == target_val
				REQ_OPERATOR.COMPARE.NOT_EQUAL:
					return str(current_val) != target_val
				_:
					Logging.err("FlagRequirement: 未知的比较操作符 str: %s" % operator)
					return false
		'int':
			var current_val = PlayerState.get_flag(flag_id)
			if current_val == null:
				current_val = 0
			var target_val = int(value)
			match operator:
				REQ_OPERATOR.COMPARE.LESS_THAN:
					return int(current_val) < target_val
				REQ_OPERATOR.COMPARE.GREATER_THAN:
					return int(current_val) > target_val
				REQ_OPERATOR.COMPARE.EQUAL:
					return int(current_val) == target_val
				REQ_OPERATOR.COMPARE.NOT_EQUAL:
					return int(current_val) != target_val
				_:
					Logging.err("FlagRequirement: 未知的比较操作符 int: %s" % operator)
					return false
		'bool':
			var current_val = PlayerState.get_flag(flag_id)
			if current_val == null:
				current_val = false
			var bool_str = str(value).to_lower()
			var target_val = bool_str == 'true' or bool_str == 't' or bool_str == '1' or bool_str == 'yes'
			if operator == REQ_OPERATOR.COMPARE.LESS_THAN:
				return bool(current_val) < target_val
			else:
				return bool(current_val) > target_val
		_:
			Logging.err('Unknown flag type: %s for flag %s' % [type, flag_id])
			return false
