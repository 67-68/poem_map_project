extends DirectionalLight2D


func request_daylight(enable: bool):
	visible = enable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	Global.request_daylight.connect(request_daylight)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
