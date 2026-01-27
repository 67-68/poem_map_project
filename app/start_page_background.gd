extends TextureRect

func on_request_black(enable: bool):
	if enable:
		create_tween().tween_property(self,'modulate',Color.BLACK,1)
	else:
		create_tween().tween_property(self,'modulate',Color.WHITE,1)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_start_black.connect(on_request_black)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
