extends CanvasModulate


func change_color(color_: Color):
	if color_:
		visible = true
		color = color_
	else:
		visible = false
		color = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.change_background_color.connect(change_color)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
