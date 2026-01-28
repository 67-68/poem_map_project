extends Node

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

# 用来展示poet
signal user_clicked(PoetData) # 值可以为空，express 点到空处，面板hide

signal request_start_black(enable: bool)

# 展示popup信息
signal request_text_popup(text: String)

signal change_background_color(color: Color) # 如果为空，disable color
signal request_rain(enable: bool)
signal request_daylight(enable: bool)

signal year_changed(year: float) #虽然可能用不到，直接使用Global year就行了，但还是发一下

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Logging.current_level = Logging.Level.DEBUG

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)

