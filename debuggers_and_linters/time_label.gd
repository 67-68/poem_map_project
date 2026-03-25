extends Label

var base_text = 'engine: timescale = '

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = base_text
	text += str(Engine.time_scale)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = base_text
	text += str(Engine.time_scale)
