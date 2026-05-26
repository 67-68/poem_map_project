class_name FlagReplaceOperator extends BaseOperator

@export var to_be_replaced_flag_id: String = ""
@export var replace_with_flag_id: String = ""

func operate():
	Logging.debug('FlagReplaceOperator: Starting operate()')

	# 校验两个 flag 都存在
	var to_be_replaced_flag = Database.flags.get(to_be_replaced_flag_id)
	var replace_with_flag = Database.flags.get(replace_with_flag_id)

	if not to_be_replaced_flag:
		Logging.err('FlagReplaceOperator: Flag %s not found in Database.flags' % to_be_replaced_flag_id)
		return

	if not replace_with_flag:
		Logging.err('FlagReplaceOperator: Flag %s not found in Database.flags' % replace_with_flag_id)
		return

	# 校验两个 flag 都是 bool 类型
	if to_be_replaced_flag.type != 'bool':
		Logging.err('FlagReplaceOperator: Flag %s is not bool type, got %s' % [to_be_replaced_flag_id, to_be_replaced_flag.type])
		return

	if replace_with_flag.type != 'bool':
		Logging.err('FlagReplaceOperator: Flag %s is not bool type, got %s' % [replace_with_flag_id, replace_with_flag.type])
		return

	# 执行替换：将被替换的 flag 设为 false，将替换后的 flag 设为 true
	to_be_replaced_flag.val_bool = false
	replace_with_flag.val_bool = true

	Logging.debug('FlagReplaceOperator: Replaced flag %s (false) with flag %s (true)' % [to_be_replaced_flag_id, replace_with_flag_id])
