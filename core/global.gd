extends Node

var year: float = 618.0
var mood: float = 0.5
var ratio_time: float = 0

# 用来展示poet
signal user_clicked(PoetData) # 值可以为空，express 点到空处，面板hide

# 展示popup信息
signal request_text_popup(text: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	ratio_time = remap(year,618,907,0,1)
	ratio_time = clampf(ratio_time, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)

