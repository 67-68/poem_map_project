extends HSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_value_no_signal(Global.ratio_time) # 不要正常修改，会左脚踩右脚升天
	# 不需要 * 100

func _on_value_changed(new_value: float) -> void:
	Global.year = lerp(Global.start_year, Global.end_year, new_value)
	print('当前年份', Global.year)
	if int(Global.year) % 10 == 0:
		Global.request_text_popup.emit('new decade %s' % int(Global.year))
 
