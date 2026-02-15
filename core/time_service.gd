extends Node

@export var speed: float = 5.0 

func _ready() -> void:
	Global.year = Global.start_year
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	Global.year += speed * delta
	Global.year_changed.emit(Global.year)
	
	Global.ratio_time = remap(Global.year,Global.start_year,Global.end_year,0,1)
	Global.ratio_time = clampf(Global.ratio_time, 0.0, 1.0)
	
func play():
	set_process(true) # 开启 _process

func pause():
	set_process(false)

func jump_to(year: float):
	if not year: return
	if Global.start_year < year and year < Global.end_year:
		Global.year = year
		Global.year_changed.emit(Global.year)
		Global.ratio_time = remap(Global.year, Global.start_year, Global.end_year, 0.0, 1.0)
		Global.ratio_time = clampf(Global.ratio_time, 0.0, 1.0)

# 增加一个控制 Engine 的开关
func pause_world(completely: bool = true):
	# 1. 停掉日历
	set_process(false) 
	
	if completely:
		# 方案 A: 彻底冻结 (适合弹窗)
		get_tree().paused = true
	else:
		# 方案 B: 慢动作 (适合过渡)
		Engine.time_scale = 0.1

func resume_world():
	# 1. 恢复日历
	set_process(true)
	
	# 2. 恢复世界
	get_tree().paused = false
	Engine.time_scale = 1.0