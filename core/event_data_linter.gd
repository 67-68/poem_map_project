extends Node

# 事件数据Linter
# 用于验证和检查事件数据的完整性和正确性
# 暂时只是加载所有事件数据，后续可以添加更多验证逻辑

## 执行Linter检查
## 目前只是加载所有事件数据，验证数据加载是否正常
func execute_linter() -> void:
	print("===== 开始执行事件数据Linter =====")
	
	# 🚨 调用DataHelper加载所有事件数据
	var event_data = DataHelper.load_event_data()
	
	if not event_data:
		push_error("事件数据加载失败！Linter终止 💀")
		return
	
	# 验证各个事件数据字典是否成功加载
	_validate_event_data(event_data)
	
	# 构建trait到事件的映射
	_build_trait_to_events_mapping(event_data)
	
	# 检查选项的时间推动和结果
	_check_option_time_and_result(event_data)
	
	print("===== 事件数据Linter执行完成 🤓☝️ =====")

## 验证事件数据的完整性
func _validate_event_data(event_data: DataHelper.EventData) -> void:
	print("\n--- 验证事件数据完整性 ---")
	
	var validation_results = []
	
	# 验证history_events
	if event_data.history_events.is_empty():
		validation_results.append("❌ history_events 为空")
	else:
		validation_results.append("✓ history_events 加载成功 (包含 %d 个事件)" % event_data.history_events.size())
	
	# 验证random_events
	if event_data.random_events.is_empty():
		validation_results.append("❌ random_events 为空")
	else:
		var total_random_events = 0
		for tag_bucket in event_data.random_events:
			total_random_events += event_data.random_events[tag_bucket].size()
		validation_results.append("✓ random_events 加载成功 (包含 %d 个事件，分 %d 个标签桶)" % [total_random_events, event_data.random_events.size()])
	
	# 验证end_random_events
	if event_data.end_random_events.is_empty():
		validation_results.append("❌ end_random_events 为空")
	else:
		validation_results.append("✓ end_random_events 加载成功 (包含 %d 个事件)" % event_data.end_random_events.size())
	
	# 验证focused_chat_data
	if event_data.focused_chat_data.is_empty():
		validation_results.append("❌ focused_chat_data 为空")
	else:
		validation_results.append("✓ focused_chat_data 加载成功 (包含 %d 个聊天)" % event_data.focused_chat_data.size())
	
	# 验证ambitions
	if event_data.ambitions.is_empty():
		validation_results.append("❌ ambitions 为空")
	else:
		validation_results.append("✓ ambitions 加载成功 (包含 %d 个野心)" % event_data.ambitions.size())
	
	# 验证traits
	if event_data.traits.is_empty():
		validation_results.append("❌ traits 为空")
	else:
		validation_results.append("✓ traits 加载成功 (包含 %d 个特质)" % event_data.traits.size())
	
	# 验证properties
	if event_data.properties.is_empty():
		validation_results.append("❌ properties 为空")
	else:
		validation_results.append("✓ properties 加载成功 (包含 %d 个属性)" % event_data.properties.size())
	
	# 验证actions
	if event_data.actions.is_empty():
		validation_results.append("❌ actions 为空")
	else:
		validation_results.append("✓ actions 加载成功 (包含 %d 个动作)" % event_data.actions.size())
	
	# 验证decisions
	if event_data.decisions.is_empty():
		validation_results.append("❌ decisions 为空")
	else:
		validation_results.append("✓ decisions 加载成功 (包含 %d 个决策)" % event_data.decisions.size())
	
	# 验证decided_events
	if event_data.decided_events.is_empty():
		validation_results.append("❌ decided_events 为空")
	else:
		validation_results.append("✓ decided_events 加载成功 (包含 %d 个已决定事件)" % event_data.decided_events.size())
	
	# 验证imaginaries
	if event_data.imaginaries.is_empty():
		validation_results.append("❌ imaginaries 为空")
	else:
		validation_results.append("✓ imaginaries 加载成功 (包含 %d 个想象)" % event_data.imaginaries.size())
	
	# 验证legendary_poems
	if event_data.legendary_poems.is_empty():
		validation_results.append("❌ legendary_poems 为空")
	else:
		validation_results.append("✓ legendary_poems 加载成功 (包含 %d 个传奇诗词)" % event_data.legendary_poems.size())
	
	# 验证normal_poem_events
	if event_data.normal_poem_events.is_empty():
		validation_results.append("❌ normal_poem_events 为空")
	else:
		validation_results.append("✓ normal_poem_events 加载成功 (包含 %d 个普通诗词事件)" % event_data.normal_poem_events.size())
	
	# 打印验证结果
	for result in validation_results:
		print(result)
	
	print("--- 验证完成 ---\n")

## 构建trait到事件的映射
func _build_trait_to_events_mapping(event_data: DataHelper.EventData) -> void:
	print("\n--- 构建Trait到事件映射 ---")
	
	var all_events = {}
	var all_trait_reqs = {}
	
	# 合并所有事件到一个桶中
	_merge_all_events(event_data, all_events)
	print("✓ 合并完成，共 %d 个事件" % all_events.size())
	
	# 第一次扫描：收集所有requirement中的trait
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_trait_requirements(event, event_uuid, all_trait_reqs)
	
	print("✓ 收集到 %d 个不同的trait requirement" % all_trait_reqs.size())
	
	# 第二次扫描：查找提供这些trait的operator
	var trait_to_events = {}
	for trait_uuid in all_trait_reqs:
		trait_to_events[trait_uuid] = []
	
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_trait_providers(event, event_uuid, trait_to_events)
	
	# 输出结果
	print("\n--- Trait到事件映射结果 ---")
	for trait_uuid in trait_to_events:
		var events = trait_to_events[trait_uuid]
		if events.size() > 0:
			print("Trait %s: 由 %d 个事件提供 -> %s" % [trait_uuid, events.size(), str(events)])

## 合并所有事件到一个字典
func _merge_all_events(event_data: DataHelper.EventData, target_dict: Dictionary) -> void:
	target_dict.merge(event_data.history_events)
	for bucket in event_data.random_events.values():
		target_dict.merge(bucket)
	target_dict.merge(event_data.end_random_events)
	target_dict.merge(event_data.ambitions)
	target_dict.merge(event_data.decided_events)
	target_dict.merge(event_data.imaginaries)
	target_dict.merge(event_data.legendary_poems)
	target_dict.merge(event_data.normal_poem_events)

## 递归收集对象中的所有trait requirement
func _collect_trait_requirements(obj: Variant, event_uuid: String, trait_reqs: Dictionary) -> void:
	if obj == null: return
	
	# 检查是否是TraitRequirement
	if obj is TraitRequirement and obj.trait_name:
		trait_reqs[obj.trait_name] = true
		return
	
	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_trait_requirements(value, event_uuid, trait_reqs)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_trait_requirements(item, event_uuid, trait_reqs)
	# 检查对象的导出属性
	elif obj is Object:
		for prop in obj.get_property_list():
			var prop_name = prop.name
			if prop_name.begins_with("_") or prop_name == "metadata":
				continue
			var value = obj.get(prop_name)
			if value != null:
				_collect_trait_requirements(value, event_uuid, trait_reqs)

## 递归收集对象中提供trait的operator
func _collect_trait_providers(obj: Variant, event_uuid: String, trait_to_events: Dictionary) -> void:
	if obj == null: return
	
	# 检查是否是TraitOperator且是ADD操作
	if obj is TraitOperator and obj.operator == REQ_OPERATOR.CRUD.ADD:
		var trait_key = obj.trait_key
		if trait_key in trait_to_events:
			trait_to_events[trait_key].append(event_uuid)
		return
	
	# 检查是否是TraitReplaceOperator
	if obj is TraitReplaceOperator:
		var trait_key = obj.replace_other_trait
		if trait_key in trait_to_events:
			trait_to_events[trait_key].append(event_uuid)
		return
	
	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_trait_providers(value, event_uuid, trait_to_events)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_trait_providers(item, event_uuid, trait_to_events)
	# 检查对象的导出属性
	elif obj is Object:
		for prop in obj.get_property_list():
			var prop_name = prop.name
			if prop_name.begins_with("_") or prop_name == "metadata":
				continue
			var value = obj.get(prop_name)
			if value != null:
				_collect_trait_providers(value, event_uuid, trait_to_events)

## 检查选项的时间推动和结果
func _check_option_time_and_result(event_data: DataHelper.EventData) -> void:
	print("\n--- 检查选项时间推动和结果 ---")
	
	var all_events = {}
	_merge_all_events(event_data, all_events)
	
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

## 检查单个事件的选项
func _check_event_options(event: Variant, event_uuid: String, violations: Array) -> void:
	if event == null: return
	
	# 获取事件的选项
	var options = []
	if event.has_method("get") and event.get("options"):
		options = event.get("options")
	elif event.options:
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
		for prop in obj.get_property_list():
			var prop_name = prop.name
			if prop_name.begins_with("_") or prop_name == "metadata":
				continue
			var value = obj.get(prop_name)
			if _has_time_operator(value):
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
		for prop in obj.get_property_list():
			var prop_name = prop.name
			if prop_name.begins_with("_") or prop_name == "metadata":
				continue
			var value = obj.get(prop_name)
			if _has_positive_result(value):
				return true
	
	return false
