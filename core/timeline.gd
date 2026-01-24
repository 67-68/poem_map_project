extends HSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_value_changed(new_value: float) -> void:
	Global.year = lerp(618.0, 907.0, new_value)
	print('当前年份', new_value * 1000)
 