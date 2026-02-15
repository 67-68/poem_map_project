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


# 用来展示poet
signal user_clicked(PoetData) # 值可以为空，express 点到空处，面板hide

signal request_start_black(enable: bool)

# 展示popup信息
signal request_text_popup(text: String)

signal change_background_color(color: Color) # 如果为空，disable color
signal request_rain(enable: bool)
signal request_daylight(enable: bool)

signal year_changed(year: float) #虽然可能用不到，直接使用Global year就行了，但还是发一下

signal poems_created(data: Array)
signal request_apply_poem(data: PoemData, poet: PoetData)
signal poem_animation_finished()

signal request_add_messager(msg: Messager)

var life_path_points: Dictionary
var poet_data: Dictionary
var poem_data: Dictionary
var factions: Dictionary
var base_province: Dictionary
var territories: Dictionary
var msger_data: Dictionary

func init():
	index_image = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	Logging.current_level = Logging.Level.DEBUG

	# 加载数据
	life_path_points = create_dict(DataLoader.load_json_model(PoetLifePoint,'path_points'))
	poet_data = create_dict(DataLoader.load_json_model(PoetData,'poet_data'))
	poem_data = create_dict(DataLoader.load_json_model(PoemData,'poem_data'))
	factions = create_dict(DataLoader.load_json_model(Faction,'factions'))
	base_province = create_dict(DataLoader.load_csv_model(Territory,'base_province')) # 州的加载。每个州不应该有sub_id
	territories = create_dict(DataLoader.load_csv_model(Territory,'territories'))
	msger_data = create_dict(DataLoader.load_json_model(MessagerData,'msger_data'))
	# 数据文件不允许使用字典！！使用list

	for d in poem_data:
		var poem_point = PoetLifePoint.new(poem_data[d].to_life_path_point_data())
		poem_point.uuid = 'poem_%s' % d
		life_path_points[poem_point.uuid] = (poem_point)

	for d in poet_data:
		poet_data[d].path_point_keys = DataHelper.find_all_values_by_membership(life_path_points,'owner_uuids',d,'uuid')

func create_dict(data: Array):
	var dict = {}
	for d in data:
		dict[d.uuid] = d
	return dict

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)
