class_name LinkerLinterRule extends BaseLinterRule
## 链接检查官
## 只管引用对不对（Trait A 被需求，但有没有人提供？Flag B 被 set，有没有在白名单里？）🤓☝️

const Logging = preload("res://core/logger.gd")
func _init():
	rule_name = "链接检查官"

func execute(event_data: Node) -> void:
	errors.clear()
	warnings.clear()
	
	Logging.info("\n--- 链接检查官开始工作 ---")
	
	var all_events = event_data.get_all_events_iterator()
	Logging.info("✓ 获取到 %d 个事件" % all_events.size())
	
	# 检查Trait供需关系
	_check_trait_supply_demand(all_events)
	
	# 检查Flag供需关系
	_check_flag_supply_demand(all_events, event_data.flags)
	
	Logging.info("--- 链接检查官工作完成 ---\n")

## 检查Trait供需关系
func _check_trait_supply_demand(all_events: Dictionary) -> void:
	Logging.info("\n--- 检查Trait供需关系 ---")
	
	var all_trait_reqs = {}
	var trait_providers = {}
	
	# 第一阶段：收集所有需求
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_trait_requirements_from_event(event, event_uuid, all_trait_reqs)
	
	Logging.info("✓ 收集到 %d 个不同的trait requirement" % all_trait_reqs.size())
	
	# 第二阶段：收集所有提供
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_trait_provisions_from_event(event, event_uuid, trait_providers)
	
	# 第三阶段：验证供需
	for trait_uuid in all_trait_reqs:
		if not trait_uuid in trait_providers or trait_providers[trait_uuid].is_empty():
			add_error("Trait %s 被需求但没有事件提供" % trait_uuid)
		else:
			Logging.info("Trait %s: 由 %d 个事件提供 -> %s" % [trait_uuid, trait_providers[trait_uuid].size(), str(trait_providers[trait_uuid])])

## 检查Flag供需关系
func _check_flag_supply_demand(all_events: Dictionary, flags_dict: Dictionary) -> void:
	Logging.info("\n--- 检查Flag供需关系 ---")
	
	var all_flag_reqs = {}
	var flag_providers = {}
	
	# 第一阶段：收集所有需求
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_flag_requirements_from_event(event, event_uuid, all_flag_reqs)
	
	Logging.info("✓ 收集到 %d 个不同的flag requirement" % all_flag_reqs.size())
	
	# 第二阶段：收集所有提供
	for event_uuid in all_events:
		var event = all_events[event_uuid]
		_collect_flag_provisions_from_event(event, event_uuid, flag_providers, flags_dict)
	
	# 第三阶段：验证供需
	for flag_uuid in all_flag_reqs:
		if not flag_uuid in flag_providers or flag_providers[flag_uuid].is_empty():
			add_error("Flag %s 被需求但没有事件提供" % flag_uuid)
		else:
			Logging.info("Flag %s: 由 %d 个事件提供 -> %s" % [flag_uuid, flag_providers[flag_uuid].size(), str(flag_providers[flag_uuid])])

## 从事件中收集trait需求（使用契约方法，拒绝反射 😡）
func _collect_trait_requirements_from_event(event: Variant, event_uuid: String, trait_reqs: Dictionary) -> void:
	if event == null: return
	
	# 使用契约方法收集需求，不使用反射
	_collect_trait_requirements_from_object_recursive(event, trait_reqs)

## 从事件中收集trait提供（使用契约方法，拒绝反射 😡）
func _collect_trait_provisions_from_event(event: Variant, event_uuid: String, trait_providers: Dictionary) -> void:
	if event == null: return
	
	# 使用契约方法收集提供，不使用反射
	_collect_trait_provisions_from_object_recursive(event, event_uuid, trait_providers)

## 从事件中收集flag需求（使用契约方法，拒绝反射 😡）
func _collect_flag_requirements_from_event(event: Variant, event_uuid: String, flag_reqs: Dictionary) -> void:
	if event == null: return
	
	# 使用契约方法收集需求，不使用反射
	_collect_flag_requirements_from_object_recursive(event, flag_reqs)

## 从事件中收集flag提供（使用契约方法，拒绝反射 😡）
func _collect_flag_provisions_from_event(event: Variant, event_uuid: String, flag_providers: Dictionary, flags_dict: Dictionary) -> void:
	if event == null: return
	
	# 使用契约方法收集提供，不使用反射
	_collect_flag_provisions_from_object_recursive(event, event_uuid, flag_providers, flags_dict)

## 递归收集对象中的trait需求（契约方法版本）
func _collect_trait_requirements_from_object_recursive(obj: Variant, trait_reqs: Dictionary) -> void:
	if obj == null: return
	
	# 🤓☝️ 鸭子类型：检查对象是否有契约方法
	if obj.has_method('get_demanded_traits'):
		var traits = obj.get_demanded_traits()
		for trait_ in traits:
			trait_reqs[trait_] = true
		return
	if obj.has_method('get_referenced_traits'):
		var traits = obj.get_referenced_traits()
		for trait_ in traits:
			trait_reqs[trait_] = true
		return

	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_trait_requirements_from_object_recursive(value, trait_reqs)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_trait_requirements_from_object_recursive(item, trait_reqs)
	# 检查对象的导出属性（最后手段，但还是比全量反射好）
	elif obj is Object:
		# 尝试获取operators数组等已知属性
		if obj.has_method('get'):
			var operators = obj.get('operators')
			if operators is Array:
				for op in operators:
					_collect_trait_requirements_from_object_recursive(op, trait_reqs)
		# 其他已知属性
		var known_properties = ['condition', 'condition_success_result', 'condition_fail_result', 'requirements', 'operators']
		for prop_name in known_properties:
			if obj.has_method('get'):
				var value = obj.get(prop_name)
				if value != null:
					_collect_trait_requirements_from_object_recursive(value, trait_reqs)

## 递归收集对象中的trait提供（契约方法版本）
func _collect_trait_provisions_from_object_recursive(obj: Variant, event_uuid: String, trait_providers: Dictionary) -> void:
	if obj == null: return
	
	# 🤓☝️ 鸭子类型：检查对象是否有契约方法
	if obj.has_method('get_provided_traits'):
		var traits = obj.get_provided_traits()
		for trait_ in traits:
			if not trait_ in trait_providers:
				trait_providers[trait_] = []
			trait_providers[trait_].append(event_uuid)
		return
	
	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_trait_provisions_from_object_recursive(value, event_uuid, trait_providers)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_trait_provisions_from_object_recursive(item, event_uuid, trait_providers)
	# 检查对象的导出属性（最后手段）
	elif obj is Object:
		if obj.has_method('get'):
			var known_properties = ['condition_success_result', 'condition_fail_result', 'operators']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null:
					_collect_trait_provisions_from_object_recursive(value, event_uuid, trait_providers)

## 递归收集对象中的flag需求（契约方法版本）
func _collect_flag_requirements_from_object_recursive(obj: Variant, flag_reqs: Dictionary) -> void:
	if obj == null: return
	
	# 🤓☝️ 鸭子类型：检查对象是否有契约方法
	if obj.has_method('get_demanded_flags'):
		var flags = obj.get_demanded_flags()
		for flag in flags:
			flag_reqs[flag] = true
		return
	if obj.has_method('get_referenced_flags'):
		var flags = obj.get_referenced_flags()
		for flag in flags:
			flag_reqs[flag] = true
		return

	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_flag_requirements_from_object_recursive(value, flag_reqs)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_flag_requirements_from_object_recursive(item, flag_reqs)
	# 检查对象的导出属性（最后手段）
	elif obj is Object:
		if obj.has_method('get'):
			var known_properties = ['condition', 'condition_success_result', 'condition_fail_result', 'requirements', 'operators']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null:
					_collect_flag_requirements_from_object_recursive(value, flag_reqs)

## 递归收集对象中的flag提供（契约方法版本）
func _collect_flag_provisions_from_object_recursive(obj: Variant, event_uuid: String, flag_providers: Dictionary, flags_dict: Dictionary) -> void:
	if obj == null: return
	
	# 🤓☝️ 鸭子类型：检查对象是否有契约方法
	if obj.has_method('get_provided_flags'):
		var flags = obj.get_provided_flags()
		for flag in flags:
			if not flag in flag_providers:
				flag_providers[flag] = []
			flag_providers[flag].append(event_uuid)
		return
	
	# 递归检查字典
	if obj is Dictionary:
		for value in obj.values():
			_collect_flag_provisions_from_object_recursive(value, event_uuid, flag_providers, flags_dict)
	# 递归检查数组
	elif obj is Array:
		for item in obj:
			_collect_flag_provisions_from_object_recursive(item, event_uuid, flag_providers, flags_dict)
	# 检查对象的导出属性（最后手段）
	elif obj is Object:
		if obj.has_method('get'):
			var known_properties = ['condition_success_result', 'condition_fail_result', 'operators']
			for prop_name in known_properties:
				var value = obj.get(prop_name)
				if value != null:
					_collect_flag_provisions_from_object_recursive(value, event_uuid, flag_providers, flags_dict)