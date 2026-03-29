@tool
class_name EventActionTagLinter extends Node

@export var start := false:
	set(value):
		start = false
		if Engine.is_editor_hint():
			printerr("在游戏打开后使用！")
		start_linter()

func start_linter() -> void:
	"""
	在游戏打开后使用！进入游戏内部，不是主界面
	
	检测
	- 是否有地区的tag没有被任何action使用
	- 是否有action不满足任何地区tag
	
	- 是否有action的action_tag没有被任何事件使用
	- 是否有事件使用了不属于任何action的tag
	
	注意：random_event使用target_tags（合并了area_tags和action_tags），所以统一检查所有标签
	"""
	print("开始检查event和action的tag...")
	# 仿造Global, 加载所有action和event
	var actions: Dictionary = Util.create_dict_from_registry(preload("res://data/tres_actions_registry.tres"))
	var random_events: Dictionary = Util.create_dict_from_registry(preload("res://data/tres_random_event_registry.tres"))
	random_events.merge(Util.create_dict_from_registry(preload("res://data/tres_normal_poem_events_registry.tres")))
	var base_province = Util.create_dict(DataLoader.load_csv_model(Territory,'base_province')) # 州的加载。每个州不应该有sub_id
	base_province.merge(Util.create_dict(DataLoader.load_csv_model(Territory,'territories')))
	
	# 创建action, area和event使用的标签的set
	var all_action_tags = {}
	var all_action_area_tags = {}
	var all_event_tags = {}  # 合并了area_tags和action_tags

	for a in actions.values():
		for t in a.action_tags:
			assign_or_add(all_action_tags,t)
		for t in a.area_tags: 
			assign_or_add(all_action_area_tags,t)
	for e in random_events.values():
		for t in e.target_tags:
			assign_or_add(all_event_tags,t)
	
	# 检查地区tag使用情况
	print("\n=== 地区tag检查 ===")
	
	# 检查是否有地区的tag没有被任何action使用
	var unused_area_tags = []
	for area_id in base_province.keys():
		var area = base_province[area_id]
		for tag in area.tags:
			if tag not in all_action_area_tags:
				unused_area_tags.append("%s (%s)" % [area_id, tag])
	
	if unused_area_tags.size() > 0:
		print("以下地区tag没有被任何action使用:")
		for tag in unused_area_tags:
			print("  - %s" % tag)
	else:
		print("所有地区tag都被action使用")
	
	# 检查是否有action不满足任何地区tag
	var invalid_action_area_tags = []
	for tag in all_action_area_tags.keys():
		var found = false
		for area in base_province.values():
			if tag in area.tags:
				found = true
				break
		if not found:
			invalid_action_area_tags.append(tag)
	
	if invalid_action_area_tags.size() > 0:
		print("以下action的地区tag不存在于任何地区:")
		for tag in invalid_action_area_tags:
			print("  - %s" % tag)
	else:
		print("所有action的地区tag都存在于地区中")
	
	# 检查action tag使用情况
	print("\n=== Action tag检查 ===")
	
	# 检查是否有action的action_tag没有被任何事件使用
	var unused_action_tags = []
	for tag in all_action_tags.keys():
		if tag not in all_event_tags:
			unused_action_tags.append(tag)
	
	if unused_action_tags.size() > 0:
		print("以下action tag没有被任何事件使用:")
		for tag in unused_action_tags:
			print("  - %s" % tag)
	else:
		print("所有action tag都被事件使用")
	
	# 检查是否有事件使用了不属于任何action的tag
	var invalid_event_action_tags = []
	for tag in all_event_tags.keys():
		if tag not in all_action_tags:
			invalid_event_action_tags.append(tag)
	
	if invalid_event_action_tags.size() > 0:
		print("以下事件使用了不属于任何action的tag:")
		for tag in invalid_event_action_tags:
			print("  - %s" % tag)
	else:
		print("所有事件的action tag都存在于action中")
	
	print("\n检查完成!")

func count_items(items):
	var dict = {}
	for item in items:
		var exist = dict.get(item)
		if not exist: dict[item] = 0
		else: dict[item] += 1
	return dict

func assign_or_add(dict: Dictionary, item):
	var exist = dict.get(item)
	if not exist: dict[item] = 0
	else: dict[item] += 1
	return dict
