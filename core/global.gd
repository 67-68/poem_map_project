extends Node

const DATA_PATH = "res://data/"
const DEFAULT_ICON_PATH = "res://assets/6768.png"
const ICON_PATH = "res://assets/profile/"
const PROVINCE_INDEX_MAP_PATH := "res://assets/maps/provinces.png"
const PERMANENT_DATA_PATH := 'res://assets/maps/'
const ADJACENCY_CACHE_PATH := 'res://assets/maps/map_connections_cache.json'
const SOUND_PATH := 'res://assets/sounds/'
const CHARACTER_PATH := 'res://assets/character/'

const PATH_NOISE = 0 # 最高可能偏移10px

const LON_MIN := 21.35
const LON_MAX := 122.28
const LAT_MAX := 45.09
const LAT_MIN := 88.31
const MAP_WIDTH := 1196
const MAP_HEIGHT := 668
# 统一的像素？你在想什么呢？这是一个独立游戏！

const FLOAT_TEXT_SCENE := preload('res://world/float_text.tscn')

var index_image: Image

var start_year := 618.0
var end_year := 907.0

var time_span := end_year - start_year
var year: float
var ratio_time: float = 0

var mood: float = 0.5

var sad_color: Color = Color.DARK_BLUE
var happy_color: Color = Color.LIGHT_YELLOW

var current_selected_poet: PoetData

# view
var slider_light_speed: int = 1
var color_2_province: Dictionary


var map: Node2D
var faction_renderer: FactionMapRenderer

var poem_stack_manager: PopupQueue
var poem_buffer: ManualBuffer

signal place_holder()
# 用来展示poet
signal user_clicked(PoetData) # 值可以为空，express 点到空处，面板hide

signal request_start_black(enable: bool)

# 展示popup信息
signal request_text_popup(text: String)
signal request_warning_toast(data: String)

signal request_rain(enable: bool)
signal request_daylight(enable: bool)

signal year_changed(year: float) #虽然可能用不到，直接使用Global year就行了，但还是发一下
signal speed_changed(speed: float) # -1 = stop

signal poems_created(data: Array)
signal request_apply_poem(data: PoemData, poet: PoetData)
signal poem_animation_finished()

signal request_add_messager(msg: Messager)
signal request_change_bg_modulate(color: Color)
signal request_restore_bg_modulate(duration: float) # -1 = forever
signal event_confirmed()

signal request_change_left_panel_visibility(enable)
signal request_event(data: BaseEvent)
signal request_event_key(key: String)
signal bubble_complete()
signal request_add_chat()
signal request_advance_time(days: int)
# event 和 chat 不同，后者是即时的，前者是可能需要等待的

signal focus_city_map(enable: bool)

var life_path_points: Dictionary
var poet_data: Dictionary
var poem_data: Dictionary
var factions: Dictionary
var base_province: Dictionary
var territories: Dictionary
var msger_data: Dictionary
var history_events: Dictionary
var random_events: Dictionary
var chat_bubble_data: Dictionary
var focused_chat_data: Dictionary
var ambitions: Dictionary
var traits: Dictionary
var properties: Dictionary
var actions: Dictionary

var event_popup_queue: PopupQueue
var event_buffer: ManualBuffer

var chat_buffer: ManualBuffer

var resolve_history_event = func(x: BaseEvent):
	request_event.emit(x)

func find_triggerable_item(uuid: String):
	"""
	如果uuid和另一个数据模型的uuid重复可能导致问题
	"""
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
	
func init():
	index_image = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	Logging.current_level = Logging.Level.DEBUG

	base_province = Util.create_dict(DataLoader.load_csv_model(Territory,'base_province')) # 州的加载。每个州不应该有sub_id
	territories = Util.create_dict(DataLoader.load_csv_model(Territory,'territories'))
	
	# 加载数据 - 使用tres registry
	factions = Util.create_dict_from_registry(preload("res://data/tres_factions_registry.tres"))
	life_path_points = Util.create_dict_from_registry(preload("res://data/tres_path_points_registry.tres"))
	poet_data = Util.create_dict_from_registry(preload("res://data/tres_poet_data_registry.tres"))
	poem_data = Util.create_dict_from_registry(preload("res://data/tres_poem_data_registry.tres"))
	msger_data = Util.create_dict_from_registry(preload("res://data/tres_msger_data_registry.tres"))
	history_events = Util.create_dict_from_registry(preload("res://data/tres_history_event_registry.tres"))
	random_events = Util.create_dict_from_registry(preload("res://data/tres_random_event_registry.tres"))
	# 似乎原本就没有chat bubble 文件
	focused_chat_data = Util.create_dict_from_registry(preload("res://data/tres_focused_chats_registry.tres"))
	ambitions = Util.create_dict_from_registry(preload("res://data/tres_ambitions_registry.tres"))
	traits = Util.create_dict_from_registry(preload("res://data/tres_traits_registry.tres"))
	properties = Util.create_dict_from_registry(preload("res://data/tres_properties_registry.tres"))
	actions = Util.create_dict_from_registry(preload("res://data/tres_actions_registry.tres")) # 场景化行动库，包含可以用来筛选事件的标签

	var cities = Util.create_dict_from_registry(preload("res://data/tres_cities_registry.tres"))
	if cities: for c_name in cities:
		var c = cities[c_name]
		var territory = territories.get(c.uuid)
		if territory: territory.merge(c)
		else: Logging.error("City %s has uuid %s that does not exist in territories" % [c.name, c.uuid])

	load_manager_and_buffers()
	
	# 添加到事件触发
	for d in history_events.values(): TimeService.register(d.target_year,event_buffer.pop_item,true,d)
	for d in poem_data.values(): TimeService.register(d.year,poem_buffer.pop_item,true,d)

	# 数据文件不允许使用字典！！使用list
	for d in poem_data:
		var data = poem_data[d].to_life_path_point_data()
		var poem_point = PoetLifePoint.new(data)
		# 这里的uv是没有问题的
		poem_point.uuid = 'poem_%s' % d
		life_path_points[poem_point.uuid] = (poem_point)

	for d in poet_data:
		poet_data[d].path_point_keys = DataHelper.find_all_values_by_membership(life_path_points,'owner_uuids',d,'uuid')
	
	if chat_bubble_data:
		for d in chat_bubble_data.values() + focused_chat_data.values(): TimeService.register(d.year,chat_buffer.pop_item,true,d)

func load_actual_positions(mesh_size):
	"""
	由map触发
	"""
	wash_positions(base_province,mesh_size)
	wash_positions(poem_data,mesh_size,true)
	wash_positions(life_path_points,mesh_size,true)
	# 这里的position没有问题，要是出问题只能是后面的问题

func load_manager_and_buffers():
	event_popup_queue = PopupQueue.new(resolve_history_event,event_confirmed) # 这里暂且使用一个signal, 如果后面想做多个事件页面一样叠在一起需要改一下manager内部设定不依赖complete signal
	event_buffer = ManualBuffer.new(event_popup_queue.add_item,history_events.values())
	# 可以给manager 加一个新的选项询问是不是暂停engine, 现在还需要自己手动处理太麻烦了
	poem_stack_manager = PopupQueue.new(_apply_poem_data,Global.poem_animation_finished)
	poem_buffer = ManualBuffer.new(poem_stack_manager.add_item,poem_data.values())

	chat_buffer = ManualBuffer.new(func(item): Global.request_add_chat.emit(item),chat_bubble_data.values() + focused_chat_data.values())

static func _apply_poem_data(_poem_data: PoemData):
	"""
	把poem data设置到view中
	"""
	var poet_data_ = Global.poet_data[_poem_data.owner_uuids[0]]
	Global.request_apply_poem.emit(_poem_data, poet_data_)

func wash_positions(items: Dictionary, mesh_size, use_position_uuid: bool = false):
	for item in items.values():
		# 尝试使用州名
		if use_position_uuid and item.location_uuid:
			var prov = base_province.get(item.location_uuid)
			if prov:
				item.position = prov.position
				item.uv_position = prov.uv_position
				item.position_dirty = false
				continue
		# 不行才使用uv
		if not item.uv_position:
			Logging.warn('an item do not have uv position!')
		item.position_dirty = false
		var pos = item.get_local_pos_use_vec3(mesh_size)
		item.position = pos

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)
