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

# 🆕 事件库：由 data/event_base/ 目录树自动加载
# - event_base_pool: 扁平化全量池 { "ns.uuid": Resource }
# - event_bases: 按顶层 base 分表 { "base_name": { "uuid": Resource } }，支持 eventbase.event_id 语法
var event_base_pool: Dictionary = {}
var event_bases: Dictionary = {}

# ════════════════════════════════════════════════════════════════
# 统一数据访问基础设施
# ════════════════════════════════════════════════════════════════
# _raw_data_pool:  { uuid: Resource }  — 全量 uuid→Resource 扁平池，O(1) 查找
# _index_by_class: { "ClassName": [uuid, ...] } — 按 class_name 的反向索引，支持类型过滤遍历
var _raw_data_pool: Dictionary = {}
var _index_by_class: Dictionary = {}


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

	# 🆕 从 data/event_base/ 自动加载事件库字典
	var eb_result = EventBaseLoader.scan()
	event_base_pool = eb_result.pool
	event_bases = eb_result.bases
	if eb_result.duplicates.size() > 0:
		Logging.err("EventBaseLoader: 检测到 %d 个 ID 冲突，请检查日志" % eb_result.duplicates.size())
	Logging.info("Database: event_bases 已加载 %d 个 Base: %s" % [event_bases.size(), str(event_bases.keys())])

	_merge_cities()
	_build_life_path_points_from_poems()
	_build_unified_index()


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
	Logging.info("=== _register_events_with_time_service called, GameState.year=%f ===" % GameState.year)
	for d in history_events.values():
		Logging.info("Registering event '%s' with target_year=%f" % [d.name if d.has_method("get_name") else d.uuid, d.target_year])
		# ⚠️ 使用 pop_specific.bind(d) 而非 pop_item，确保每个事件触发时弹出自己而非 items[0]
		TimeService.register(d.target_year, GameState.event_buffer.pop_specific.bind(d), d.name, d.epitaph_text, true, d)
	for d in poem_data.values():
		TimeService.register(d.year, GameState.poem_buffer.pop_item, d.name, '', true, d)


func _register_chat_with_time_service() -> void:
	if chat_bubble_data:
		for d in chat_bubble_data.values() + focused_chat_data.values():
			TimeService.register(d.year, GameState.chat_buffer.pop_item, 'focused_chat_name_placeholder', '', true, d)




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


# ════════════════════════════════════════════════════════════════
# Phase 3: 类型化 Getter 方法
# ════════════════════════════════════════════════════════════════
# 这些方法是外部代码访问数据的推荐方式。内部仍直接操作 dict 以保证性能。
# 后续私有化 dict 后，这些 getter 将成为唯一访问通道。

func get_trait(uuid: String):
	return traits.get(uuid)

func get_property(uuid: String):
	return properties.get(uuid)

func get_flag(uuid: String):
	return flags.get(uuid)

func get_imaginary(uuid: String):
	return imaginaries.get(uuid)

func get_action(uuid: String):
	return actions.get(uuid)

func get_focused_chat(uuid: String):
	return focused_chat_data.get(uuid)

func get_chat_bubble(uuid: String):
	return chat_bubble_data.get(uuid)

func get_ambition(uuid: String):
	return ambitions.get(uuid)

func get_decision(uuid: String):
	return decisions.get(uuid)

func get_npc_document(uuid: String):
	return npc_document.get(uuid)

func get_state_transistor(uuid: String):
	return state_transistors.get(uuid)

func get_poem(uuid: String):
	return poem_data.get(uuid)

func get_poet(uuid: String):
	return poet_data.get(uuid)

func get_faction(uuid: String):
	return factions.get(uuid)

func get_province(uuid: String):
	return base_province.get(uuid)

func get_territory(uuid: String):
	return territories.get(uuid)

func get_msger(uuid: String):
	return msger_data.get(uuid)

func get_tag(uuid: String):
	return tags.get(uuid)

func get_event_option(uuid: String):
	return event_options.get(uuid)

func get_poem_taste(uuid: String):
	return poem_taste.get(uuid)

func get_life_path_point(uuid: String):
	return life_path_points.get(uuid)

func get_history_event(uuid: String):
	return history_events.get(uuid)

func get_normal_poem_event(uuid: String):
	return normal_poem_events.get(uuid)

func get_legendary_poem(uuid: String):
	return legendary_poems.get(uuid)

func get_end_random_event(uuid: String):
	return end_random_events.get(uuid)

func get_random_event_bucket(main_tag: String) -> Dictionary:
	return random_events.get(main_tag, {})

func get_state_transistors_all() -> Dictionary:
	return state_transistors

func get_actions_all() -> Dictionary:
	return actions

func get_traits_all() -> Dictionary:
	return traits

func get_properties_all() -> Dictionary:
	return properties

func get_flags_all() -> Dictionary:
	return flags

func get_imaginaries_all() -> Dictionary:
	return imaginaries

func get_focused_chats_all() -> Dictionary:
	return focused_chat_data

func get_chat_bubbles_all() -> Dictionary:
	return chat_bubble_data

func get_history_events_all() -> Dictionary:
	return history_events

func get_normal_poem_events_all() -> Dictionary:
	return normal_poem_events

func get_legendary_poems_all() -> Dictionary:
	return legendary_poems

func get_end_random_events_all() -> Dictionary:
	return end_random_events

func get_random_events_all() -> Dictionary:
	return random_events

func get_poem_data_all() -> Dictionary:
	return poem_data

func get_poet_data_all() -> Dictionary:
	return poet_data

func get_life_path_points_all() -> Dictionary:
	return life_path_points

func get_factions_all() -> Dictionary:
	return factions

func get_decisions_all() -> Dictionary:
	return decisions

func get_msger_data_all() -> Dictionary:
	return msger_data

func get_base_province_all() -> Dictionary:
	return base_province

func get_territories_all() -> Dictionary:
	return territories

func get_ambitions_all() -> Dictionary:
	return ambitions

func get_event_options_all() -> Dictionary:
	return event_options

func get_poem_taste_all() -> Dictionary:
	return poem_taste

func get_npc_document_all() -> Dictionary:
	return npc_document

func get_event_base_pool_all() -> Dictionary:
	return event_base_pool


# ════════════════════════════════════════════════════════════════
# Phase 2: 统一数据访问入口
# ════════════════════════════════════════════════════════════════

## 统一数据查找入口。
##
## 支持多种 key 格式：
##   1. "base_name.event_id" — 点号语法，对应 event_bases 分表查找
##   2. uuid — 直接命中 _raw_data_pool
##   3. 后缀匹配 — _"ns.uuid" 池中以 uuid 后缀匹配（如 "event_intro_745"）
##
## 参数:
##   key:         查找键（uuid / 点号语法）
##   class_filter: 可选，限定 class_name（如 "BaseEvent"、"FocusedChat"），
##                 非空时仅返回该类型资源，类型不匹配返回 null
##   silent:      静默模式，不打印 warning（用于内部批量调用）
##
## 返回:
##   Resource 实例，未找到时返回 null
##
func resolve(key: String, class_filter: String = "", silent: bool = false):
	if key.is_empty():
		return null

	# ── 策略 1: 点号语法 "base_name.event_id" → event_bases 查表 ──
	if key.contains("."):
		var dot_pos = key.find(".")
		var base_name = key.substr(0, dot_pos)
		var event_id = key.substr(dot_pos + 1)
		if event_bases.has(base_name) and event_bases[base_name].has(event_id):
			var res = event_bases[base_name][event_id]
			if _check_class_filter(res, class_filter):
				return res

	# ── 策略 2: 直接命中 _raw_data_pool ──
	if _raw_data_pool.has(key):
		var res = _raw_data_pool[key]
		if _check_class_filter(res, class_filter):
			return res

	# ── 策略 3: 后缀匹配（"ns.uuid" 池中以 uuid 后缀匹配 key） ──
	for full_id in _raw_data_pool:
		if full_id.ends_with("." + key):
			var res = _raw_data_pool[full_id]
			if _check_class_filter(res, class_filter):
				return res

	if not silent:
		Logging.warn("resolve: key '%s' 未找到" % key)
	return null


## 获取指定 class_name 的所有资源列表。
## 通过 _index_by_class 反向索引实现 O(1) 类型过滤。
func get_all_of_class(cls_name: String) -> Array:
	if _index_by_class.has(cls_name):
		var uuids = _index_by_class[cls_name]
		var result: Array = []
		for u in uuids:
			if _raw_data_pool.has(u):
				result.append(_raw_data_pool[u])
		return result
	return []


func _check_class_filter(res: Variant, class_filter: String) -> bool:
	"""校验 resource 是否匹配 class_filter，空 filter 视为匹配"""
	if class_filter.is_empty():
		return true
	if res == null:
		return false
	var cls_name = _resolve_resource_class_name(res)
	return cls_name == class_filter


# ════════════════════════════════════════════════════════════════
# Phase 1: 统一数据索引构建
# ════════════════════════════════════════════════════════════════

func _build_unified_index() -> void:
	"""构建统一数据池 _raw_data_pool 和反向类索引 _index_by_class。
	
	扫描所有已知 Dictionary，提取具有 uuid 字段的 Resource 加入扁平池，
	并按 class_name（如 BaseEvent、FocusedChat、Trait 等）建立反向索引。
	
	设计原则：
	- 不破坏现有 dict 访问，向后兼容
	- 运行时调用一次，O(n) 全量扫描
	- uuid 冲突时 warn 并跳过（保留先写入者）
	"""
	_raw_data_pool.clear()
	_index_by_class.clear()
	Logging.info("Database: 开始构建统一数据索引...")

	# ── 平铺字典扫描 ──
	_scan_flat_dict(history_events, "history_events")
	_scan_flat_dict(end_random_events, "end_random_events")
	_scan_flat_dict(chat_bubble_data, "chat_bubble_data")
	_scan_flat_dict(focused_chat_data, "focused_chat_data")
	_scan_flat_dict(ambitions, "ambitions")
	_scan_flat_dict(traits, "traits")
	_scan_flat_dict(properties, "properties")
	_scan_flat_dict(actions, "actions")
	_scan_flat_dict(decisions, "decisions")
	_scan_flat_dict(decided_events, "decided_events")
	_scan_flat_dict(imaginaries, "imaginaries")
	_scan_flat_dict(tags, "tags")
	_scan_flat_dict(flags, "flags")
	_scan_flat_dict(life_path_points, "life_path_points")
	_scan_flat_dict(poem_taste, "poem_taste")
	_scan_flat_dict(npc_document, "npc_document")
	_scan_flat_dict(event_options, "event_options")
	_scan_flat_dict(state_transistors, "state_transistors")
	_scan_flat_dict(legendary_poems, "legendary_poems")
	_scan_flat_dict(normal_poem_events, "normal_poem_events")
	_scan_flat_dict(poet_data, "poet_data")
	_scan_flat_dict(poem_data, "poem_data")
	_scan_flat_dict(factions, "factions")
	_scan_flat_dict(msger_data, "msger_data")
	_scan_flat_dict(base_province, "base_province")
	_scan_flat_dict(territories, "territories")

	# ── 特殊：random_events 是嵌套结构 { main_tag: { uuid: Resource } } ──
	for bucket_key in random_events:
		_scan_flat_dict(random_events[bucket_key], "random_events.%s" % str(bucket_key))

	# ── 特殊：event_base_pool key 是 "ns.uuid"，resource 有独立 uuid ──
	for full_id in event_base_pool:
		_index_resource(event_base_pool[full_id], "event_base:%s" % full_id)

	var pool_size = _raw_data_pool.size()
	var class_count = _index_by_class.size()
	Logging.info("Database: 统一索引构建完成: 池内 %d 条目, %d 个类已索引" % [pool_size, class_count])


func _scan_flat_dict(dict: Dictionary, source_desc: String) -> void:
	"""扫描平铺字典的所有值，对 Resource 类型执行索引"""
	for key in dict:
		var val = dict[key]
		if val is Resource:
			_index_resource(val, "%s.%s" % [source_desc, str(key)])


func _index_resource(res: Resource, source_desc: String) -> void:
	"""提取 resource 的 uuid 和 class_name，写入 _raw_data_pool 和 _index_by_class"""
	var uuid = _extract_uuid_from_resource(res)
	if uuid.is_empty():
		return

	if _raw_data_pool.has(uuid):
		Logging.warn("_build_unified_index: uuid 冲突 '%s' (来源: %s), 跳过" % [uuid, source_desc])
		return

	_raw_data_pool[uuid] = res

	var cls_name = _resolve_resource_class_name(res)
	if not cls_name.is_empty():
		if not _index_by_class.has(cls_name):
			_index_by_class[cls_name] = []
		_index_by_class[cls_name].append(uuid)


static func _extract_uuid_from_resource(res: Resource) -> String:
	"""从 Resource 提取 uuid，优先 'uuid' 字段，兜底 'id' 字段"""
	if "uuid" in res:
		var val = res.get("uuid")
		if val is String and not val.is_empty():
			return val
	if "id" in res:
		var val = res.get("id")
		if val is String and not val.is_empty():
			return val
	return ""


static func _resolve_resource_class_name(res: Resource) -> String:
	"""获取 Resource 的 class_name 字符串（通过 script.get_global_name()）
	
	对具有 class_name 定义的 GDScript 资源有效（如 BaseEvent、FocusedChat 等），
	对纯引擎 Resource 或无脚本实例返回空字符串。
	"""
	var script_obj = res.get_script()
	if script_obj and script_obj.has_method("get_global_name"):
		return script_obj.get_global_name()
	return ""
