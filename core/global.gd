extends Node

const DATA_PATH = "res://data/"
const DEFAULT_ICON = "res://assets/6768.png"
const ICON_PATH = "res://assets/profile/"
const PROVINCE_INDEX_MAP_PATH := "res://assets/maps/provinces.png"
const PERMANENT_DATA_PATH := 'res://assets/maps/'
const ADJACENCY_CACHE_PATH := 'res://assets/maps/map_connections_cache.json'
const SOUND_PATH := 'res://assets/sounds/'

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
signal request_narrative(data: HistoryEventData)

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
signal history_event_confirmed()

signal bubble_complete()
signal request_create_bubble(node: Node2D, text: String)

var life_path_points: Dictionary
var poet_data: Dictionary
var poem_data: Dictionary
var factions: Dictionary
var base_province: Dictionary
var territories: Dictionary
var msger_data: Dictionary
var event_data: Dictionary

var history_event_stack_manager: PopupQueue
var history_event_buffer: ManualBuffer

var resolve_history_event = func(x: HistoryEventData):
	request_narrative.emit(x)

func init():
	index_image = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	Logging.current_level = Logging.Level.DEBUG

	base_province = Util.create_dict(DataLoader.load_csv_model(Territory,'base_province')) # 州的加载。每个州不应该有sub_id
	territories = Util.create_dict(DataLoader.load_csv_model(Territory,'territories'))
	factions = Util.create_dict(DataLoader.load_json_model(Faction,'factions'))

	# 加载数据
	life_path_points = Util.create_dict(DataLoader.load_json_model(PoetLifePoint,'path_points'))
	poet_data = Util.create_dict(DataLoader.load_json_model(PoetData,'poet_data'))
	poem_data = Util.create_dict(DataLoader.load_json_model(PoemData,'poem_data'))
	msger_data = Util.create_dict(DataLoader.load_json_model(MessagerData,'msger_data'))
	event_data = Util.create_dict(DataLoader.load_json_model(HistoryEventData,'history_event_data'))
	
	load_manager_and_buffers()
	
	# 添加到事件触发
	for d in event_data.values(): TimeService.register(d.year,history_event_buffer.pop_item)
	for d in poem_data.values(): TimeService.register(d.year,poem_buffer.pop_item)

	# 数据文件不允许使用字典！！使用list
	for d in poem_data:
		var poem_point = PoetLifePoint.new(poem_data[d].to_life_path_point_data())
		poem_point.uuid = 'poem_%s' % d
		life_path_points[poem_point.uuid] = (poem_point)

	for d in poet_data:
		poet_data[d].path_point_keys = DataHelper.find_all_values_by_membership(life_path_points,'owner_uuids',d,'uuid')

func load_actual_positions(mesh_size):
	"""
	由map触发
	"""
	wash_positions(base_province,mesh_size)
	wash_positions(poem_data,mesh_size,true)
	wash_positions(life_path_points,mesh_size,true)

func load_manager_and_buffers():
	history_event_stack_manager = PopupQueue.new(resolve_history_event,history_event_confirmed) # 这里暂且使用一个signal, 如果后面想做多个事件页面一样叠在一起需要改一下manager内部设定不依赖complete signal
	history_event_buffer = ManualBuffer.new(history_event_stack_manager.add_item,event_data.values())
	# 可以给manager 加一个新的选项询问是不是暂停engine, 现在还需要自己手动处理太麻烦了
	poem_stack_manager = PopupQueue.new(_apply_poem_data,Global.poem_animation_finished)
	poem_buffer = ManualBuffer.new(poem_stack_manager.add_item,poem_data.values())	

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
			breakpoint
		item.position_dirty = false
		var pos = item.get_local_pos_use_vec3(mesh_size)
		item.position = pos

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)