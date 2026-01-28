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
	
		



