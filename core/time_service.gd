extends Node

@export var _speed: float = 3

@export var speed: float:
	set(val):
		_speed = val
		Global.speed_changed.emit(val)
	get():
		return _speed

var time_start := false

# 1. 史书全卷 (Master Database)：只读，永远不删元素
# 结构: [{"time": 758.1, "callback": func1, "is_dynamic": false}]
var master_timeline: Array[Dictionary] = []

# 2. 待办清单 (Active Queue)：动态消耗，会被清空和重建
var event_queue: Array[Dictionary] = []

func _ready() -> void:
	Global.year = Global.start_year
	pause()
	
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	Global.year += speed * delta * 0.1
	Global.year_changed.emit(Global.year)
	
	# 你文档里写的进度驱动 
	Global.ratio_time = clampf(remap(Global.year, Global.start_year, Global.end_year, 0, 1), 0.0, 1.0)

	# 正常的时间流逝消耗
	while not event_queue.is_empty() and Global.year >= event_queue[0].time:
		var event = event_queue.pop_front()
		if event.callback.is_valid():
			event.callback.call()
	
func speed_up():
	if not speed + 9 > 30:
		speed += 9
	else:
		Logging.warn('speed can not be higher than 30')

func slow_down():
	if not (speed - 9) < 3:
		speed -= 9
	else:
		Logging.warn('speed can not be lower than 5')


# --- 注册接口 ---
func register(trigger_time: float, function: Callable, save_to_history: bool = true):
	var event_data = {"time": trigger_time, "callback": function}
	
	# 动态事件（比如信使移动）只需进当前队列；剧本事件需要进史书
	if save_to_history:
		master_timeline.append(event_data)
		# 史书不需要每时每刻排序，只在重建时排序即可，但保险起见：
		master_timeline.sort_custom(func(a, b): return a.time < b.time)
	
	# 如果事件发生在未来，塞进当前待办
	if trigger_time >= Global.year:
		event_queue.append(event_data)
		event_queue.sort_custom(func(a, b): return a.time < b.time)

# --- 时空穿梭核心接口 (对应你文档的 jump_to)  ---
func jump_to(new_year: float):
	Logging.info("Time jumped to: %s" % new_year)
	Global.year = new_year
	Global.year_changed.emit(Global.year)
	Global.ratio_time = clampf(remap(Global.year, Global.start_year, Global.end_year, 0, 1), 0.0, 1.0)
	
	_rebuild_queue_from_master()

func _rebuild_queue_from_master():
	event_queue.clear() # 1. 撕毁当前待办清单
	
	# 2. 从史书中抄录未来
	for event in master_timeline:
		if event.time >= Global.year:
			event_queue.append(event)
			
	# 3. 重新排序 (其实如果 master 是有序的，这一步甚至可以省掉，但为了防御性编程，排一下不亏)
	event_queue.sort_custom(func(a, b): return a.time < b.time)
	Logging.info("Queue rebuilt. Pending events: %d" % event_queue.size())
	
func play():
	set_process(true) # 开启 _process
	time_start = true
	Global.speed_changed.emit(speed)

func pause():
	set_process(false)
	time_start = false
	Global.speed_changed.emit(-1)

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
