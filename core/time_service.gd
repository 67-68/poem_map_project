extends Node

signal future_event_registered(event_data: Dictionary)
signal on_xun_tick()
signal on_month_tick()

@export var _speed: float = 3

@export var speed: float:
	set(val):
		_speed = val
		Global.speed_changed.emit(val)
	get():
		return _speed

var time_start := false

# 年号词典：[起始年份, 结束年份, 年号名称, 使用"年"还是"载"]
const ERA_TABLE = [
	# --- 初唐：打天下与贞观之治 ---
	[618, 627, "武德", "年"], # 唐高祖 李渊
	[627, 650, "贞观", "年"], # 唐太宗 李世民
	[650, 656, "永徽", "年"], # 唐高宗 李治 (起手式)
	[656, 661, "显庆", "年"],
	[661, 664, "龙朔", "年"],
	[664, 666, "麟德", "年"],
	[666, 668, "乾封", "年"],
	[668, 670, "总章", "年"],
	[670, 674, "咸亨", "年"],
	[674, 676, "上元", "年"],
	[676, 679, "仪凤", "年"],
	[679, 680, "调露", "年"],
	[680, 681, "永隆", "年"],
	[681, 682, "开耀", "年"],
	[682, 683, "永淳", "年"],
	[683, 684, "弘道", "年"],
	# --- 武周代唐：改名狂魔武则天 ---
	[684, 685, "光宅", "年"], # 此年极乱，嗣圣/文明被我无情抹除了
	[685, 689, "垂拱", "年"],
	[689, 690, "永昌", "年"],
	[690, 692, "天授", "年"], # 就在这年，大唐变成了武周
	[692, 694, "长寿", "年"],
	[694, 695, "延载", "年"],
	[695, 696, "万岁登封", "年"], # 不要问我为什么叫这么中二的名字
	[696, 697, "万岁通天", "年"],
	[697, 698, "神功", "年"],
	[698, 700, "圣历", "年"],
	[700, 701, "久视", "年"],
	[701, 705, "长安", "年"],
	# --- 盛唐：复辟与极盛 ---
	[705, 707, "神龙", "年"], # 神龙政变，唐中宗复辟
	[707, 710, "景龙", "年"],
	[710, 712, "景云", "年"], # 唐睿宗
	[712, 713, "先天", "年"], # 唐玄宗 李隆基上号
	[713, 742, "开元", "年"], # 最牛逼的时代来了
	# --- 中唐：安史之乱与藩镇割据 ---
	[742, 756, "天宝", "载"], # 唯一用"载"的时代开始了
	[756, 758, "至德", "载"], # 肃宗在灵武登基，继续用"载"
	[758, 760, "乾元", "年"], # 恢复用"年"
	[760, 762, "上元", "年"],
	[762, 763, "宝应", "年"], # 代宗
	[763, 765, "广德", "年"],
	[765, 766, "永泰", "年"],
	[766, 780, "大历", "年"],
	[780, 784, "建中", "年"], # 德宗
	[784, 785, "兴元", "年"],
	[785, 805, "贞元", "年"],
	[805, 806, "永贞", "年"], # 顺宗 (二王八司马事件)
	[806, 821, "元和", "年"], # 宪宗 (元和中兴)
	# --- 晚唐：牛李党争与宦官专权 ---
	[821, 825, "长庆", "年"], # 穆宗
	[825, 827, "宝历", "年"], # 敬宗
	[827, 836, "太和", "年"], # 文宗 (甘露之变)
	[836, 841, "开成", "年"],
	[841, 847, "会昌", "年"], # 武宗 (会昌灭佛)
	[847, 860, "大中", "年"], # 宣宗 (大中之治)
	[860, 874, "咸通", "年"], # 懿宗
	[874, 880, "乾符", "年"], # 僖宗 (黄巢起义开始)
	[880, 881, "广明", "年"],
	[881, 885, "中和", "年"],
	[885, 888, "光启", "年"],
	[888, 889, "文德", "年"],
	# --- 终局：大厦将倾 ---
	[889, 890, "龙纪", "年"], # 昭宗
	[890, 892, "大顺", "年"],
	[892, 894, "景福", "年"],
	[894, 898, "乾宁", "年"],
	[898, 901, "光化", "年"],
	[901, 904, "天复", "年"],
	[904, 907, "天祐", "年"]  # 哀帝 (907年被朱温篡位，大唐剧终)
]

# 1. 史书全卷 (Master Database)：只读，永远不删元素
# 结构: [{"time": 758.1, "callback": func1, "is_dynamic": false}]
var master_timeline: Array[Dictionary] = []

# 2. 待办清单 (Active Queue)：动态消耗，会被清空和重建
var event_queue: Array[Dictionary] = []

# 在 TimeService 顶部记录上一次运算时的总天数
var _last_total_days: int = 0
var current_xun := "上旬"
const DAYS_PER_YEAR: int = 360 # 标准化历法，一年 360 天，每月 30 天

func _ready() -> void:
	Global.request_advance_time.connect(func(days):
		advance_time(days)
	)
	on_xun_tick.connect(func():
		Logging.info("Xun tick: %s" % current_xun))
	Global.year = Global.start_year
	_last_total_days = int(Global.year * DAYS_PER_YEAR)
	Engine.time_scale = 1
	pause()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	# 1. 浮点时间匀速流逝 (保留你原有的半即时逻辑)
	Global.year += speed * delta * 0.01 # 之前太太太快了
	Global.year_changed.emit(Global.year)
	
	# 2. 检查浮点数队列 (你原有的逻辑)
	while not event_queue.is_empty() and Global.year >= event_queue[0].time:
		var event = event_queue.pop_front()
		if event.callback.is_valid():
			pause_world(true) # 关键！触发事件时必须强制暂停游戏，防止弹窗地狱！
			event.callback.call()

	_emit_time_events()
	
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
func register(trigger_time: float, function: Callable, save_to_history: bool = true, entity: GameEntity = null):
	var event_data = {"time": trigger_time, "callback": function, "entity": entity}
	
	# 动态事件（比如信使移动）只需进当前队列；剧本事件需要进史书
	if save_to_history:
		master_timeline.append(event_data)
		# 史书不需要每时每刻排序，只在重建时排序即可，但保险起见：
		master_timeline.sort_custom(func(a, b): return a.time < b.time)
	
	# 如果事件发生在未来，塞进当前待办
	if trigger_time >= Global.year:
		event_queue.append(event_data)
		event_queue.sort_custom(func(a, b): return a.time < b.time)
		future_event_registered.emit(event_data)


# --- 修改 1：修正 jump_to ---
func jump_to(new_year: float):
	Logging.info("Time jumped to: %s" % new_year)
	Global.year = new_year
	# 💀 极度重要：同步底层天数缓存，防止 _process 醒来后疯狂补帧！
	_last_total_days = int(Global.year * DAYS_PER_YEAR) 
	
	Global.year_changed.emit(Global.year)
	Global.ratio_time = clampf(remap(Global.year, Global.start_year, Global.end_year, 0, 1), 0.0, 1.0)
	
	_rebuild_queue_from_master()


# --- 修改 2：重写 advance_time，复用 _process 的发报逻辑！ ---
func advance_time(days_to_add: int):
	Logging.info("时间开始跃迁，推进 %d 天..." % days_to_add)
	
	# 1. 极其务实：直接改浮点年份
	Global.year += days_to_add / float(DAYS_PER_YEAR)
	Global.year_changed.emit(Global.year)
	Global.ratio_time = clampf(remap(Global.year, Global.start_year, Global.end_year, 0, 1), 0.0, 1.0)
	
	# 2. 模拟 _process 里的天数跨越来发信号 (复用代码，拒绝复制粘贴！)
	_emit_time_events()

func _emit_time_events():
	var current_total_days = int(Global.year * DAYS_PER_YEAR)
	if current_total_days > _last_total_days:
		var days_passed = current_total_days - _last_total_days
		for i in range(days_passed):
			var simulation_day = _last_total_days + i + 1
			var day_of_month = (simulation_day % 30)
			
			if day_of_month == 9 or day_of_month == 19 or day_of_month == 29:
				on_xun_tick.emit()
				current_xun = get_xun_text(day_of_month)
			if day_of_month == 29:
				breakpoint
				on_month_tick.emit()
				
		# 💀 极度重要：完事后必须对齐标记！
		_last_total_days = current_total_days 
	
	# 3. 检查是否有队列事件被越过！
	_check_event_queue()

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
	resume_world()
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

# --- 年号相关静态方法 ---
# 将年份转换为年号文本的静态方法
func get_era_text(year: int) -> String:
	var era_text = "未知年号"
	for era in ERA_TABLE:
		if year >= era[0] and year <= era[1]:
			var era_year_num = year - era[0] + 1
			var num_str = _get_chinese_number(era_year_num)
			
			# 拼装：比如 "天宝 十四 载"
			era_text = "%s %s %s" % [era[2], num_str, era[3]]
			break
	return era_text

# 一个简单的数字转中文辅助函数（1-99够用了）
func _get_chinese_number(num: int) -> String:
	if num == 1: return "元" # 第一年永远叫元年/元载
	
	var digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if num <= 10: return digits[num]
	if num < 20: return "十" + digits[num % 10]
	
	var tens = num / 10.0
	var ones = num % 10
	var res = digits[int(tens)] + "十"
	if ones > 0: res += digits[ones]
	return res


# 抽离出来的队列检查方法（复用你原本 _process 里的逻辑）
func _check_event_queue():
	while not event_queue.is_empty() and Global.year >= event_queue[0].time:
		var event = event_queue.pop_front()
		if event.callback.is_valid():
			Logging.info("触发历史待办事件！设定时间: %f" % event.time)
			event.callback.call()

func get_xun_text(day: int) -> String:
	"""
	注意！不使用一般的计数方法
	直接根据9，19，29判定！！！
	"""
	if day == 9:
		return "中旬"
	elif day == 19:
		return "下旬"
	else:
		return "上旬"
