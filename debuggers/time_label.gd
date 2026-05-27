extends Label

var base_text = 'engine: timescale = '
var base_day_text = '\ncurrent day:'

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = base_text
	text += str(Engine.time_scale)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = base_text
	text += str(Engine.time_scale)
	text += base_day_text
	text += str(TimeService.current_day)
