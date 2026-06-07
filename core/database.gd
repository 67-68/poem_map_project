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
var feihualing_imageries: Dictionary
var tags: Dictionary

var legendary_poems: Dictionary
var normal_poem_events: Dictionary

var flags: Dictionary

var life_path_points: Dictionary

var poem_taste: Dictionary

var npc_document: Dictionary

var event_options: Dictionary

var state_transistors: Dictionary


func _init() -> void:
	index_image = load(GameConfig.PROVINCE_INDEX_MAP_PATH).get_image()
	Logging.current_level = Logging.Level.DEBUG

	# 显式加载翻译：确保 Resource 脚本能访问翻译
	var trans_path = "res://data/translations/dynamic_events.zh.translation"
	if ResourceLoader.exists(trans_path):
		var trans = load(trans_path)
		if trans is Translation:
			TranslationServer.add_translation(trans)
			Logging.info("Database: translations loaded from %s" % trans_path)
		else:
			Logging.warn("Database: loaded translation is not a Translation resource (got %s)" % typeof(trans))
	else:
		Logging.warn("Database: translation file not found at %s" % trans_path)
	Logging.info("Database: tr(FEIHUALING_FAIL) = '%s'" % TranslationServer.translate("FEIHUALING_FAIL"))

	base_province = Util.create_dict(DataLoader.load_csv_model(Territory, 'base_province'))
	territories = Util.create_dict(DataLoader.load_csv_model(Territory, 'territories'))

	factions = Util.create_dict_from_registry(load("res://data/tres_factions_registry.tres"))
	flags = Util.create_dict_from_registry(load("res://data/flags_registry.tres"))
	life_path_points = Util.create_dict_from_registry(load("res://data/tres_path_points_registry.tres"))
	poet_data = Util.create_dict_from_registry(load("res://data/tres_poet_data_registry.tres"))
	poem_data = Util.create_dict_from_registry(load("res://data/tres_poem_data_registry.tres"))
	msger_data = Util.create_dict_from_registry(load("res://data/tres_msger_data_registry.tres"))
	tags = Util.create_dict_from_registry(load("res://data/tres_tags_registry.tres"))
	event_options = Util.create_dict_from_registry(load("res://data/event_options_registry.tres"))
	poem_taste = Util.create_dict_from_registry(load("res://data/poem_taste_registry.tres"))
	npc_document = Util.create_dict_from_registry(load("res://data/npc_document_registry.tres"))
	#breakpoint
	state_transistors = Util.create_dict_from_registry(load("res://data/tres_state_transistors_registry.tres"))

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
	# 飞花令意象库：从主意象字典中筛选环境类意象
	feihualing_imageries = {}
	for uuid in imaginaries:
		if uuid.begins_with("environment:"):
			feihualing_imageries[uuid] = imaginaries[uuid]
	Logging.info("Database: feihualing_imageries loaded with %d entries" % feihualing_imageries.size())
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
	for r in random_events:
		if random_events.get(r).get(uuid):
			return random_events.get(r).get(uuid)
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
	if event_options.get(uuid):
		return event_options[uuid]


func find_from_all(key: String):
	# 遍历所有资源库，按 key（UUID/ID）查找第一个匹配的条目
	# random_events 是嵌套结构（main_tag -> uuid -> item），需展开搜索

	# ── 核心数据 ──
	if poet_data.has(key):
		Logging.info("find_from_all: found key '%s' in poet_data" % key)
		return poet_data[key]
	if poem_data.has(key):
		Logging.info("find_from_all: found key '%s' in poem_data" % key)
		return poem_data[key]
	if factions.has(key):
		Logging.info("find_from_all: found key '%s' in factions" % key)
		return factions[key]
	if base_province.has(key):
		Logging.info("find_from_all: found key '%s' in base_province" % key)
		return base_province[key]
	if territories.has(key):
		Logging.info("find_from_all: found key '%s' in territories" % key)
		return territories[key]
	if msger_data.has(key):
		Logging.info("find_from_all: found key '%s' in msger_data" % key)
		return msger_data[key]

	# ── 事件数据 ──
	if history_events.has(key):
		Logging.info("find_from_all: found key '%s' in history_events" % key)
		return history_events[key]
	if normal_poem_events.has(key):
		Logging.info("find_from_all: found key '%s' in normal_poem_events" % key)
		return normal_poem_events[key]
	if legendary_poems.has(key):
		Logging.info("find_from_all: found key '%s' in legendary_poems" % key)
		return legendary_poems[key]

	# random_events 是嵌套的，遍历所有 tag bucket
	for tag_bucket in random_events:
		if random_events[tag_bucket].has(key):
			Logging.info("find_from_all: found key '%s' in random_events[%s]" % [key, tag_bucket])
			return random_events[tag_bucket][key]

	if end_random_events.has(key):
		Logging.info("find_from_all: found key '%s' in end_random_events" % key)
		return end_random_events[key]
	if chat_bubble_data.has(key):
		Logging.info("find_from_all: found key '%s' in chat_bubble_data" % key)
		return chat_bubble_data[key]
	if focused_chat_data.has(key):
		Logging.info("find_from_all: found key '%s' in focused_chat_data" % key)
		return focused_chat_data[key]
	if ambitions.has(key):
		Logging.info("find_from_all: found key '%s' in ambitions" % key)
		return ambitions[key]
	if traits.has(key):
		Logging.info("find_from_all: found key '%s' in traits" % key)
		return traits[key]
	if properties.has(key):
		Logging.info("find_from_all: found key '%s' in properties" % key)
		return properties[key]
	if actions.has(key):
		Logging.info("find_from_all: found key '%s' in actions" % key)
		return actions[key]
	if decisions.has(key):
		Logging.info("find_from_all: found key '%s' in decisions" % key)
		return decisions[key]
	if decided_events.has(key):
		Logging.info("find_from_all: found key '%s' in decided_events" % key)
		return decided_events[key]

	# ── 其他数据 ──
	if imaginaries.has(key):
		Logging.info("find_from_all: found key '%s' in imaginaries" % key)
		return imaginaries[key]
	if tags.has(key):
		Logging.info("find_from_all: found key '%s' in tags" % key)
		return tags[key]
	if flags.has(key):
		Logging.info("find_from_all: found key '%s' in flags" % key)
		return flags[key]
	if life_path_points.has(key):
		Logging.info("find_from_all: found key '%s' in life_path_points" % key)
		return life_path_points[key]
	if poem_taste.has(key):
		Logging.info("find_from_all: found key '%s' in poem_taste" % key)
		return poem_taste[key]
	if npc_document.has(key):
		Logging.info("find_from_all: found key '%s' in npc_document" % key)
		return npc_document[key]
	if event_options.has(key):
		Logging.info("find_from_all: found key '%s' in event_options" % key)
		return event_options[key]
	if state_transistors.has(key):
		Logging.info("find_from_all: found key '%s' in state_transistors" % key)
		return state_transistors[key]

	Logging.warn("find_from_all: key '%s' not found in any resource library" % key)
	return null


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


## 查询 NPC 的指定属性值。
##
## 从 npc_document[npc_id].prop[prop_name] 中读取。
## 如果 NPC 文档不存在或属性未定义，返回 0 并记录错误日志。
##
## 参数:
##   npc_id:    NPC 的 UUID（如 "libai"、"dufu"）
##   prop_name: 属性名（如 "TALENT"、"HEALTH"），建议使用 ENUMS.PROPS 枚举
##
## 返回:
##   int — 属性值，不存在时返回 0
##
## 典型用途:
##   NpcBatchCheckOperator 在 on_enter 阶段批量检定 NPC 时调用。
func query_prop(npc_id: String, prop_name: String) -> int:
	var doc = npc_document.get(npc_id)
	if doc == null:
		Logging.err('Database.query_prop: npc_document not found for "%s"' % npc_id)
		return 0

	# doc.prop 是 @export var prop: Dictionary = {}（NPCDocument），保证非 null
	var props: Dictionary = doc.prop
	if props.is_empty():
		Logging.warn('Database.query_prop: npc_document["%s"].prop is empty (no properties defined)' % npc_id)
		return 0
	if not props.has(prop_name):
		Logging.warn('Database.query_prop: npc "%s" has no property "%s" defined in prop dict' % [npc_id, prop_name])
		return 0

	var val = props[prop_name]
	if val is int:
		return val

	Logging.warn('Database.query_prop: npc "%s" property "%s" is not int (got %s), converting' % [npc_id, prop_name, typeof(val)])
	return int(val)


func get_random_events(main_tag: String = '') -> Dictionary:
	if main_tag.is_empty():
		Logging.info('get_random_events: no main tag provided, returning all events')
		var all_events = {}
		for tag_bucket in random_events:
			all_events.merge(random_events[tag_bucket])
		return all_events
	else:
		# 前缀匹配：用 main_tag 匹配所有桶 key（如 action:main:baiye 匹配 action:main:baiye:general）
		var matching_events = {}
		var matched_buckets: Array[String] = []
		for bucket_key in random_events:
			if TagManager.prefix_match(main_tag, bucket_key):
				matching_events.merge(random_events[bucket_key])
				matched_buckets.append(bucket_key)

		if matching_events.is_empty():
			Logging.err('get_random_events: no bucket prefix-matched main tag: ' + main_tag)
		else:
			Logging.info('get_random_events: main tag "%s" prefix-matched buckets: %s' % [main_tag, str(matched_buckets)])
		return matching_events
