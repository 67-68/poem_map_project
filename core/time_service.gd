extends Node

@export var speed: float = 5.0 
@export var trigger_time_list := []
@export var time_2_func := {}
@export var current_time_idx: int # 记录当前走到了哪个time in time list

func _ready() -> void:
	Global.year = Global.start_year
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	Global.year += speed * delta
	Global.year_changed.emit(Global.year)
	
	Global.ratio_time = remap(Global.year,Global.start_year,Global.end_year,0,1)
	Global.ratio_time = clampf(Global.ratio_time, 0.0, 1.0)

	if Global.year > trigger_time_list[current_time_idx] and current_time_idx != -1:
		var previous_time: float
		while true:
			previous_time = trigger_time_list[current_time_idx]
			if not current_time_idx >= trigger_time_list.size() and not previous_time == trigger_time_list[current_time_idx]:
				for function in time_2_func[trigger_time_list[current_time_idx]]:
					function.call()
			else:
				Logging.info('未来没有更多事件了')
				current_time_idx = -1
			current_time_idx += 1

func register(time: float, function: Callable):
	for i in range(trigger_time_list):
		if trigger_time_list[i] > time:
			trigger_time_list.insert(i,time) # 这里可能会有一些性能问题
	if not time in time_2_func: time_2_func[time] = []
	time_2_func[time].append(function)

	# 在未来没有事件的情况下添加
	current_time_idx = trigger_time_list.size() - 2

	if time < trigger_time_list[current_time_idx]:
		Logging.warn('一个过去的触发事件被添加到了 %s' % time)
		current_time_idx += 1
	
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