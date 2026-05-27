extends Node

var index_image: Image

var poet_data: Dictionary
var poem_data: Dictionary
var factions: Dictionary
var base_province: Dictionary
var territories: Dictionary
var msger_data: Dictionary

var history_events: Dictionary
var random_events: Dictionary
var end_random_events: Dictionary

var chat_bubble_data: Dictionary
var focused_chat_data: Dictionary
var ambitions: Dictionary
var traits: Dictionary
var properties: Dictionary
var actions: Dictionary
var decisions: Dictionary
var decided_events: Dictionary
var imaginaries: Dictionary
var tags: Dictionary

var legendary_poems: Dictionary
var normal_poem_events: Dictionary

var flags: Dictionary

var life_path_points: Dictionary


func _init() -> void:
	index_image = load(GameConfig.PROVINCE_INDEX_MAP_PATH).get_image()
	Logging.current_level = Logging.Level.DEBUG

	base_province = Util.create_dict(DataLoader.load_csv_model(Territory, 'base_province'))
	territories = Util.create_dict(DataLoader.load_csv_model(Territory, 'territories'))

	factions = Util.create_dict_from_registry(load("res://data/tres_factions_registry.tres"))
	flags = Util.create_dict_from_registry(load("res://data/flags_registry.tres"))
	life_path_points = Util.create_dict_from_registry(load("res://data/tres_path_points_registry.tres"))
	poet_data = Util.create_dict_from_registry(load("res://data/tres_poet_data_registry.tres"))
	poem_data = Util.create_dict_from_registry(load("res://data/tres_poem_data_registry.tres"))
	msger_data = Util.create_dict_from_registry(load("res://data/tres_msger_data_registry.tres"))
	tags = Util.create_dict_from_registry(load("res://data/tres_tags_registry.tres"))

	# 🚨 使用DataHelper的static函数统一加载所有事件相关数据
	var event_data = DataHelper.load_event_data()
	history_events = event_data.history_events
	random_events = event_data.random_events
	end_random_events = event_data.end_random_events
	focused_chat_data = event_data.focused_chat_data
	ambitions = event_data.ambitions
	traits = event_data.traits
	properties = event_data.properties
	actions = event_data.actions
	decisions = event_data.decisions
	decided_events = event_data.decided_events
	imaginaries = event_data.imaginaries
	legendary_poems = event_data.legendary_poems
	normal_poem_events = event_data.normal_poem_events

	_merge_cities()
	_build_life_path_points_from_poems()


func _ready() -> void:
	_register_events_with_time_service()
	_register_chat_with_time_service()


func _merge_cities() -> void:
	var cities = Util.create_dict_from_registry(load("res://data/tres_cities_registry.tres"))
	if cities:
		for c_name in cities:
			var c = cities[c_name]
			var province = base_province.get(c.uuid)
			if province:
				province.merge(c)
			else:
				Logging.err("City %s has uuid %s that does not exist in territories" % [c.name, c.uuid])


func _build_life_path_points_from_poems() -> void:
	for d in poem_data:
		var data = poem_data[d].to_life_path_point_data()
		var poem_point = PoetLifePoint.new(data)
		poem_point.uuid = 'poem_%s' % d
		life_path_points[poem_point.uuid] = poem_point

	for d in poet_data:
		poet_data[d].path_point_keys = DataHelper.find_all_values_by_membership(
			life_path_points, 'owner_uuids', d, 'uuid'
		)


func _register_events_with_time_service() -> void:
	for d in history_events.values():
		TimeService.register(d.target_year, GameState.event_buffer.pop_item, d.name, d.epitaph_text, true, d)
	for d in poem_data.values():
		TimeService.register(d.year, GameState.poem_buffer.pop_item, d.name, '', true, d)


func _register_chat_with_time_service() -> void:
	if chat_bubble_data:
		for d in chat_bubble_data.values() + focused_chat_data.values():
			TimeService.register(d.year, GameState.chat_buffer.pop_item, 'focused_chat_name_placeholder', '', true, d)


func find_triggerable_item(uuid: String):
	if normal_poem_events.get(uuid):
		return normal_poem_events[uuid]
	if poem_data.get(uuid):
		return poem_data[uuid]
	if msger_data.get(uuid):
		return msger_data[uuid]
	if history_events.get(uuid):
		return history_events[uuid]
	if chat_bubble_data.get(uuid):
		return chat_bubble_data[uuid]
	if focused_chat_data.get(uuid):
		return focused_chat_data[uuid]
	if decided_events.get(uuid):
		return decided_events[uuid]
	for main_tag in random_events:
		if random_events[main_tag].get(uuid):
			return random_events[main_tag][uuid]
	if actions.get(uuid):
		return actions[uuid]
	if ambitions.get(uuid):
		return ambitions[uuid]
	if traits.get(uuid):
		return traits[uuid]
	if properties.get(uuid):
		return properties[uuid]
	if decisions.get(uuid):
		return decisions[uuid]
	if end_random_events.get(uuid):
		return end_random_events[uuid]


func load_actual_positions(mesh_size) -> void:
	wash_positions(base_province, mesh_size)
	wash_positions(poem_data, mesh_size, true)
	wash_positions(life_path_points, mesh_size, true)


func wash_positions(items: Dictionary, mesh_size, use_position_uuid: bool = false) -> void:
	for item in items.values():
		if use_position_uuid and item.location_uuid:
			var prov = base_province.get(item.location_uuid)
			if prov:
				item.position = prov.position
				item.uv_position = prov.uv_position
				item.position_dirty = false
				continue
		if not item.uv_position:
			Logging.warn('an item do not have uv position!')
		item.position_dirty = false
		var pos = item.get_local_pos_use_vec3(mesh_size)
		item.position = pos


func get_active_imaginaries() -> Dictionary:
	var active_imaginaries = {}
	for imaginary_uuid in imaginaries:
		var imaginary = imaginaries[imaginary_uuid]
		if imaginary.basic_imaginaries.size() > 0:
			active_imaginaries[imaginary_uuid] = imaginary
	return active_imaginaries


func get_random_events(main_tag: String = '') -> Dictionary:
	if main_tag.is_empty():
		Logging.info('get_random_events: no main tag provided, returning all events')
		var all_events = {}
		for tag_bucket in random_events:
			all_events.merge(random_events[tag_bucket])
		return all_events
	else:
		if random_events.has(main_tag):
			Logging.info('get_random_events: returning events for main tag: ' + main_tag)
			return random_events[main_tag]
		else:
			Logging.err('get_random_events: main tag not found: ' + main_tag)
			return {}
