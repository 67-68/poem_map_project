extends CanvasLayer # 或者你的根节点类型

@onready var label_era: Label = $Margin/Panel/Margin/VBox/Label_Era
@onready var label_greg: Label = $Margin/Panel/Margin/VBox/Label_Gregorian

func on_start_end_btn_pressed():
	if TimeService.time_start:
		TimeService.pause()
	else: TimeService.play()

func _on_next_poet_button_pressed() -> void:
	if Global.current_selected_poet:
		TimeService.jump_to(
			Global.current_selected_poet.get_next_path_point(
			Global.year).
		point_year)
	else:
		Global.request_text_popup.emit('choose a poet')

func speed_up():
	TimeService.speed_up()

func slow_down():
	TimeService.slow_down()

func _ready():
	# 监听时间流动
	Global.year_changed.connect(_on_year_changed)
	Global.speed_changed.connect(on_speed_changed)
	
func on_speed_changed(spd: float):
	if spd == -1:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "烂柯(⏸)"
	elif spd >= 30:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "驷马难追(4)"
	elif spd >= 21:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "光阴似箭(3)"
	elif spd >= 12:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "时不我待(2)"
	elif spd >= 3:
		$Margin/Panel/Margin/VBox/HBox/SpeedIndicator.text = "度日如年(1)"

	
func _on_year_changed(current_float_year: float):
	var current_year = int(floor(current_float_year))
	# 比如 755.5 -> 0.5 * 12 + 1 = 7月
	var current_month = int(floor((current_float_year - current_year) * 12.0)) + 1 
	
	# 1. 更新公元小字 (直白，功能性)
	label_greg.text = "公元 %d 年 %d 月" % [current_year, current_month]
	
	# 2. 查表计算大唐年号 (氛围，沉浸感)
	label_era.text = TimeService.get_era_text(current_year)
