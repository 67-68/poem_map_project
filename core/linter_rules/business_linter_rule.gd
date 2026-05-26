class_name BusinessLinterRule extends BaseLinterRule
## 业务规则检查官
## 专门负责校验策划的业务规则（拿了好处必须消耗时间等）🤓☝️

func _init():
	rule_name = "业务规则检查官"

func execute(event_data: DataHelper.EventData) -> void:
	errors.clear()
	warnings.clear()
	
	print("\n--- 业务规则检查官开始工作 ---")
	
	var all_events = event_data.get_all_events_iterator()
	
	# 检查选项的时间推动和结果
	_check_option_time_and_result(all_events)
	
	# 检查Operator完整性
	_check_operator_completeness(all_events)
	
	print("--- 业务规则检查官工作完成 ---\n")

## 检查选项的时间推动和结果
func _check_option_time_and_result(all_events: Dictionary) -> void:
	print("\n--- 检查选项时间推动和结果 ---")
	
	var violations = []
	
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_check_event_options(event, event_uuid, violations)
	
	if violations.is_empty():
		print("✓ 所有选项都正确处理了时间推动")
	else:
		print("❌ 发现 %d 个违规：" % violations.size())
		for violation in violations:
			print("  - %s" % violation)
			add_error(violation)

## 检查单个事件的选项
func _check_event_options(event: Variant, event_uuid: String, violations: Array) -> void:
	if event == null: return
	
	# 获取事件的选项
	var options = []
	# 跳过没有options属性的事件类型
	if event.has_method("get"):
		if event.get("options"):
			options = event.get("options")
	elif event.has_method("get_property_list"):
		if event.get_property_list().any(func(prop): return prop.name == "options"):
			if event.options:
				options = event.options
	
	for option in options:
		if option == null: continue
		_check_single_option(option, event_uuid, violations)

## 检查单个选项
func _check_single_option(option: Variant, event_uuid: String, violations: Array) -> void:
	if option == null: return
	
	var choice_result = null
	if option.has_method("get"):
		choice_result = option.get("choice_result")
	else:
		choice_result = option.choice_result if "choice_result" in option else null
	
	if choice_result == null: return
	
	# 检查是否有时间推动
	var has_time_operator = _has_time_operator(choice_result)
	
	# 检查是否有positive result
	var has_positive_result = _has_positive_result(choice_result)
	
	if has_positive_result and not has_time_operator:
		var option_desc = option.get("description") if option.has_method("get") else option.description if "description" in option else "unknown"
		violations.append("事件 %s 的选项 '%s' 有结果但没有时间推动" % [event_uuid, option_desc])

## 递归检查对象中是否包含TimeOperator
func _has_time_operator(obj: Variant) -> bool:
	if obj == null: return false
	
	if obj is TimeOperator:
		return true
	
	if obj is Dictionary:
		for value in obj.values():
			if _has_time_operator(value):
				return true
	elif obj is Array:
		for item in obj:
			if _has_time_operator(item):
				return true
	elif obj is Object:
		# 检查已知属性，避免全量反射
		if obj.has_method('get'):
			var known_properties = ['condition_success_result', 'condition_fail_result', 'operators', 'choice_result']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null and _has_time_operator(value):
					return true
	
	return false

## 递归检查对象中是否包含positive result
func _has_positive_result(obj: Variant) -> bool:
	if obj == null: return false
	
	# 检查正面的emotion获取（value > 0）
	if obj is EmotionOperator and obj.value > 0:
		return true
	
	# 检查正面的property获取（value > 0）
	if obj is PropertyOperator and obj.value > 0:
		return true
	
	if obj is Dictionary:
		for value in obj.values():
			if _has_positive_result(value):
				return true
	elif obj is Array:
		for item in obj:
			if _has_positive_result(item):
				return true
	elif obj is Object:
		# 检查已知属性，避免全量反射
		if obj.has_method('get'):
			var known_properties = ['condition_success_result', 'condition_fail_result', 'operators', 'choice_result']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null and _has_positive_result(value):
					return true
	
	return false

## 检查Operator完整性
func _check_operator_completeness(all_events: Dictionary) -> void:
	print("\n--- 检查Operator完整性 ---")
	
	var operator_errors = []
	
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_validate_event_operators_recursive(event, event_uuid, operator_errors)
	
	if operator_errors.is_empty():
		print("✓ 所有Operator都是完整的")
	else:
		print("❌ 发现 %d 个Operator完整性问题：" % operator_errors.size())
		for error in operator_errors:
			print("  - %s" % error)
			add_error(error)

## 递归验证事件中的Operator完整性
func _validate_event_operators_recursive(obj: Variant, event_uuid: String, errors: Array) -> void:
	if obj == null: return
	
	# 检查TraitOperator
	if obj is TraitOperator:
		if not obj.str_traits.is_empty():
			return  # str_traits设置正确，无需检查枚举
		if obj._trait_key == null:
			errors.append("事件 %s 的TraitOperator缺少str_traits和_trait_key设置" % event_uuid)
		return
	
	# 检查TraitReplaceOperator
	if obj is TraitReplaceOperator:
		if obj._replace_other_trait == null:
			errors.append("事件 %s 的TraitReplaceOperator缺少_replace_other_trait设置" % event_uuid)
		if obj._to_be_replaced_trait == null:
			errors.append("事件 %s 的TraitReplaceOperator缺少_to_be_replaced_trait设置" % event_uuid)
		return
	
	# 检查FlagOperator
	if obj is FlagOperator:
		if obj.flag_id.is_empty():
			errors.append("事件 %s 的FlagOperator缺少flag_id设置" % event_uuid)
		return
	
	# 检查PropertyOperator
	if obj is PropertyOperator:
		if obj.property.is_empty():
			errors.append("事件 %s 的PropertyOperator缺少property设置" % event_uuid)
		return
	
	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_validate_event_operators_recursive(value, event_uuid, errors)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_validate_event_operators_recursive(item, event_uuid, errors)
	# 检查对象的导出属性（仅检查已知属性）
	elif obj is Object:
		if obj.has_method('get'):
			var known_properties = ['condition_success_result', 'condition_fail_result', 'operators', 'choice_result']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null:
					_validate_event_operators_recursive(value, event_uuid, errors)