extends HSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_value_no_signal(GameState.ratio_time) # 不要正常修改，会左脚踩右脚升天
	# 不需要 * 100

func _on_value_changed(new_value: float) -> void:
	GameState.year = lerp(GameState.start_year, GameState.end_year, new_value)
	print('当前年份', GameState.year)
	if int(GameState.year) % 10 == 0:
		EventBus.request_toast.emit('new decade %s' % int(GameState.year), 0)
 
