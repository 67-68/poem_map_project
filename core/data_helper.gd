@tool
class_name DataHelper extends RefCounted

## 事件数据容器，用于统一返回所有事件相关的数据
class EventData:
	var history_events: Dictionary
	var random_events: Dictionary
	var end_random_events: Dictionary
	var focused_chat_data: Dictionary
	var ambitions: Dictionary
	var traits: Dictionary
	var properties: Dictionary
	var actions: Dictionary
	var decisions: Dictionary
	var decided_events: Dictionary
	var imaginaries: Dictionary
	var legendary_poems: Dictionary
	var normal_poem_events: Dictionary
	var flags: Dictionary

	func _init(
		h_history_events: Dictionary,
		h_random_events: Dictionary,
		h_end_random_events: Dictionary,
		h_focused_chat_data: Dictionary,
		h_ambitions: Dictionary,
		h_traits: Dictionary,
		h_properties: Dictionary,
		h_actions: Dictionary,
		h_decisions: Dictionary,
		h_decided_events: Dictionary,
		h_imaginaries: Dictionary,
		h_legendary_poems: Dictionary,
		h_normal_poem_events: Dictionary,
		h_flags: Dictionary
	):
		history_events = h_history_events
		random_events = h_random_events
		end_random_events = h_end_random_events
		focused_chat_data = h_focused_chat_data
		ambitions = h_ambitions
		traits = h_traits
		properties = h_properties
		actions = h_actions
		decisions = h_decisions
		decided_events = h_decided_events
		imaginaries = h_imaginaries
		legendary_poems = h_legendary_poems
		normal_poem_events = h_normal_poem_events
		flags = h_flags

	## 获取所有事件的统一迭代器
	## 返回一个包含所有事件的字典，key为事件UUID，value为事件对象
	## 这样Linter就不需要知道具体有哪些事件类型 🤓☝️
	func get_all_events_iterator() -> Dictionary:
		var all_events = {}
		all_events.merge(history_events)
		for bucket in random_events.values():
			all_events.merge(bucket)
		all_events.merge(end_random_events)
		all_events.merge(ambitions)
		all_events.merge(decided_events)
		all_events.merge(imaginaries)
		all_events.merge(legendary_poems)
		all_events.merge(normal_poem_events)
		return all_events

## 加载所有事件相关的数据
## 返回 EventData 对象，包含所有事件相关的字典
static func load_event_data() -> EventData:
	var history_events = Util.create_dict_from_registry(load("res://data/tres_history_event_registry.tres"))
	
	var random_events = {
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_BAIYE_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_bai_ye_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_JIAOYOU_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_jiao_you_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_DENGGAO_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_deng_gao_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_FANGSHI_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_fang_shi_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_FENGZHAO_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_feng_zhao_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_MAIN_DUZHUO_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_du_zhuo_registry.tres")),
		ENUMS.to_action_str(ENUMS.ACTION_TAGS.ACTION_SPECIAL_DEEPSEEK_GENERAL): Util.create_dict_from_registry(load("res://data/tres_random_event_special_registry.tres")),
		'random_events': Util.create_dict_from_registry(load("res://data/random_events_registry.tres"))
	}
	
	var end_random_events = Util.create_dict_from_registry(load("res://data/tres_end_random_events_registry.tres"))
	var focused_chat_data = Util.create_dict_from_registry(load("res://data/tres_focused_chats_registry.tres"))
	var ambitions = Util.create_dict_from_registry(load("res://data/tres_ambitions_registry.tres"))
	
	var temp_traits = Util.create_dict_from_registry(load("res://data/tres_traits_registry.tres"))
	var traits = {}
	# 处理traits的UUID转换
	for t in temp_traits.values():
		t.uuid = t.uuid.replace('__', ':')
		traits[t.uuid] = t
	
	var properties = Util.create_dict_from_registry(load("res://data/tres_properties_registry.tres"))
	var actions = Util.create_dict_from_registry(load("res://data/tres_actions_registry.tres"))
	var decisions = Util.create_dict_from_registry(load("res://data/tres_decisions_registry.tres"))
	var decided_events = Util.create_dict_from_registry(load("res://data/tres_decided_events_registry.tres"))
	var imaginaries = Util.create_dict_from_registry(load("res://data/tres_imaginaries_registry.tres"))
	var legendary_poems = Util.create_dict_from_registry(load("res://data/tres_legendary_poems_registry.tres"))
	var normal_poem_events = Util.create_dict_from_registry(load("res://data/tres_normal_poem_events_registry.tres"))

	# 🚨 flags registry 可能尚未生成，先设为空字典
	var flags = {}
	var flags_registry = load("res://data/flags_registry.tres")
	if flags_registry:
		flags = Util.create_dict_from_registry(flags_registry)
	else:
		# 在tool模式下Logging可能不可用，直接使用print
		if Engine.is_editor_hint():
			print_rich("[color=yellow][WARN] flags_registry.tres not found, flags will be empty[/color]")
		else:
			Logging.warn("flags_registry.tres not found, flags will be empty")

	return EventData.new(
		history_events,
		random_events,
		end_random_events,
		focused_chat_data,
		ambitions,
		traits,
		properties,
		actions,
		decisions,
		decided_events,
		imaginaries,
		legendary_poems,
		normal_poem_events,
		flags
	)

## 查找所有匹配条件的项，并返回指定属性的列表
## 对应 Python 的 list(generator)
static func find_all_values_by_filter(
	data: Dictionary,
    match_key: String, 
	match_value: Variant, 
	result_key: String
) -> Array:
	# 在 Godot 4 里，我们可以用函数式写法，虽然它不是惰性的，但很整洁
	# 注意：data.values() 会创建一个数组拷贝，如果数据量极大，建议用下面的手动循环
	return data.values().filter(
		func(p): return p.get(match_key) == match_value
	).map(
		func(p): return p.get(result_key)
	)


## 查找第一个匹配条件的项，找到即停止（这才是真正的高效）
## 对应 Python 的 next(generator, default)
static func find_value_by_filter(
    data: Dictionary,
	match_key: String, 
	match_value: Variant, 
	result_key: String, 
	default: Variant = null
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data.values():
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p.get(result_key)
			
	return default

static func find_item_by_filter(
    data: Dictionary,
	match_key: String, 
	match_value: Variant, 
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data.values():
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p
	return

static func find_item_by_filter_list(
    data: Array,
	match_key: String, 
	match_value: Variant, 
) -> Variant:
	# 为了性能，这里我们拒绝一切华而不实的函数式包装 😡
	# 手动循环是实现“惰性查找（找到就跑）”在 GDScript 里的唯一真理
	for p in data:
		# get() 相当于 Python 的 getattr()，既支持 Dictionary 也支持 Object/Resource
		if p.get(match_key) == match_value:
			return p
	return

## 查找所有项，判断 match_value 是否在对象的 match_key 数组中
static func find_all_values_by_membership(
	data,
	match_key: String, 
	match_value: Variant, 
	result_key: String
) -> Array:
	# 使用函数式写法。注意：p.get(match_key) 拿出来必须是个 Array 或 Dictionary
	return data.values().filter(
		func(p): 
			var list = p.get(match_key)
			# 这里的 in 相当于 Python 的 in，支持 Array, Dict, String
			return list != null and match_value in list
	).map(
		func(p): return p.get(result_key)
	)


## 查找第一个匹配项，一旦发现 match_value 在 list 中就立即返回
static func find_value_by_membership(
	data,
	match_key: String, 
	match_value: Variant, 
	result_key: String, 
	default: Variant = null
) -> Variant:
	# 还是那句话，找第一个请务必使用手动循环，拒绝性能浪费 😡
	for p in data.values():
		var list = p.get(match_key)
		
		# 防御性编程：确保 list 存在且确实包含目标
		if list != null and match_value in list:
			return p.get(result_key)
			
	return default
