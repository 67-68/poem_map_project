extends Node

signal future_event_registered(event_data: Dictionary)
signal on_xun_tick()
signal on_month_tick()
signal on_season_tick()
signal on_year_tick()

var time_start := false

# 年号词典：[起始年份, 结束年份, 年号名称, 使用"年"还是"载"]
static var ERA_TABLE = [
	# --- 初唐：打天下与贞观之治 ---
	[618, 627, "CODE_TIME_SERVICE_EF11B5079E", "CODE_TIME_SERVICE_62EF900A8F"], # 唐高祖 李渊
	[627, 650, "CODE_TIME_SERVICE_403E603F8E", "CODE_TIME_SERVICE_62EF900A8F"], # 唐太宗 李世民
	[650, 656, "CODE_TIME_SERVICE_0D5E3BBCFF", "CODE_TIME_SERVICE_62EF900A8F"], # 唐高宗 李治 (起手式)
	[656, 661, "CODE_TIME_SERVICE_E95AAC3C95", "CODE_TIME_SERVICE_62EF900A8F"],
	[661, 664, "CODE_TIME_SERVICE_F85E33B67D", "CODE_TIME_SERVICE_62EF900A8F"],
	[664, 666, "CODE_TIME_SERVICE_768FFF6C9D", "CODE_TIME_SERVICE_62EF900A8F"],
	[666, 668, "CODE_TIME_SERVICE_A496F11152", "CODE_TIME_SERVICE_62EF900A8F"],
	[668, 670, "CODE_TIME_SERVICE_B2F2889795", "CODE_TIME_SERVICE_62EF900A8F"],
	[670, 674, "CODE_TIME_SERVICE_13DF179D96", "CODE_TIME_SERVICE_62EF900A8F"],
	[674, 676, "CODE_TIME_SERVICE_DB90AAFB25", "CODE_TIME_SERVICE_62EF900A8F"],
	[676, 679, "CODE_TIME_SERVICE_B07BC6AE9A", "CODE_TIME_SERVICE_62EF900A8F"],
	[679, 680, "CODE_TIME_SERVICE_6EFB5FBAAD", "CODE_TIME_SERVICE_62EF900A8F"],
	[680, 681, "CODE_TIME_SERVICE_52D8404CDB", "CODE_TIME_SERVICE_62EF900A8F"],
	[681, 682, "CODE_TIME_SERVICE_8005F72353", "CODE_TIME_SERVICE_62EF900A8F"],
	[682, 683, "CODE_TIME_SERVICE_65002B56BD", "CODE_TIME_SERVICE_62EF900A8F"],
	[683, 684, "CODE_TIME_SERVICE_9945881634", "CODE_TIME_SERVICE_62EF900A8F"],
	# --- 武周代唐：改名狂魔武则天 ---
	[684, 685, "CODE_TIME_SERVICE_DB1ED4AFEC", "CODE_TIME_SERVICE_62EF900A8F"], # 此年极乱，嗣圣/文明被我无情抹除了
	[685, 689, "CODE_TIME_SERVICE_94C28C1B7D", "CODE_TIME_SERVICE_62EF900A8F"],
	[689, 690, "CODE_TIME_SERVICE_4CE0CCE1D6", "CODE_TIME_SERVICE_62EF900A8F"],
	[690, 692, "CODE_TIME_SERVICE_A032500609", "CODE_TIME_SERVICE_62EF900A8F"], # 就在这年，大唐变成了武周
	[692, 694, "CODE_TIME_SERVICE_EE29E8AAA4", "CODE_TIME_SERVICE_62EF900A8F"],
	[694, 695, "CODE_TIME_SERVICE_997643A9ED", "CODE_TIME_SERVICE_62EF900A8F"],
	[695, 696, "CODE_TIME_SERVICE_E0A29CB71B", "CODE_TIME_SERVICE_62EF900A8F"], # 不要问我为什么叫这么中二的名字
	[696, 697, "CODE_TIME_SERVICE_AE6E896497", "CODE_TIME_SERVICE_62EF900A8F"],
	[697, 698, "CODE_TIME_SERVICE_F26B3DA78A", "CODE_TIME_SERVICE_62EF900A8F"],
	[698, 700, "CODE_TIME_SERVICE_08B1AD763F", "CODE_TIME_SERVICE_62EF900A8F"],
	[700, 701, "CODE_TIME_SERVICE_6C5C004D20", "CODE_TIME_SERVICE_62EF900A8F"],
	[701, 705, "CODE_TIME_SERVICE_1F1F9CFE35", "CODE_TIME_SERVICE_62EF900A8F"],
	# --- 盛唐：复辟与极盛 ---
	[705, 707, "CODE_TIME_SERVICE_76B14E9510", "CODE_TIME_SERVICE_62EF900A8F"], # 神龙政变，唐中宗复辟
	[707, 710, "CODE_TIME_SERVICE_7F0F044408", "CODE_TIME_SERVICE_62EF900A8F"],
	[710, 712, "CODE_TIME_SERVICE_6433E7CCD9", "CODE_TIME_SERVICE_62EF900A8F"], # 唐睿宗
	[712, 713, "CODE_TIME_SERVICE_20CFB0C092", "CODE_TIME_SERVICE_62EF900A8F"], # 唐玄宗 李隆基上号
	[713, 742, "CODE_TIME_SERVICE_EBEE17546E", "CODE_TIME_SERVICE_62EF900A8F"], # 最牛逼的时代来了
	# --- 中唐：安史之乱与藩镇割据 ---
	[742, 756, "CODE_TIME_SERVICE_A3812802ED", "CODE_TIME_SERVICE_42C209DA45"], # 唯一用"载"的时代开始了
	[756, 758, "CODE_TIME_SERVICE_3E78DF1CAF", "CODE_TIME_SERVICE_42C209DA45"], # 肃宗在灵武登基，继续用"载"
	[758, 760, "CODE_TIME_SERVICE_586BDF6287", "CODE_TIME_SERVICE_62EF900A8F"], # 恢复用"年"
	[760, 762, "CODE_TIME_SERVICE_DB90AAFB25", "CODE_TIME_SERVICE_62EF900A8F"],
	[762, 763, "CODE_TIME_SERVICE_820487222A", "CODE_TIME_SERVICE_62EF900A8F"], # 代宗
	[763, 765, "CODE_TIME_SERVICE_143A14DCBD", "CODE_TIME_SERVICE_62EF900A8F"],
	[765, 766, "CODE_TIME_SERVICE_BE459DFCE3", "CODE_TIME_SERVICE_62EF900A8F"],
	[766, 780, "CODE_TIME_SERVICE_2A3DCD2909", "CODE_TIME_SERVICE_62EF900A8F"],
	[780, 784, "CODE_TIME_SERVICE_95A8ABDB21", "CODE_TIME_SERVICE_62EF900A8F"], # 德宗
	[784, 785, "CODE_TIME_SERVICE_44D1B109F0", "CODE_TIME_SERVICE_62EF900A8F"],
	[785, 805, "CODE_TIME_SERVICE_BC72E0C796", "CODE_TIME_SERVICE_62EF900A8F"],
	[805, 806, "CODE_TIME_SERVICE_996CA5380A", "CODE_TIME_SERVICE_62EF900A8F"], # 顺宗 (二王八司马事件)
	[806, 821, "CODE_TIME_SERVICE_F9160160E9", "CODE_TIME_SERVICE_62EF900A8F"], # 宪宗 (元和中兴)
	# --- 晚唐：牛李党争与宦官专权 ---
	[821, 825, "CODE_TIME_SERVICE_52EB72A19A", "CODE_TIME_SERVICE_62EF900A8F"], # 穆宗
	[825, 827, "CODE_TIME_SERVICE_AB0C667C28", "CODE_TIME_SERVICE_62EF900A8F"], # 敬宗
	[827, 836, "CODE_TIME_SERVICE_BD75E4D1F4", "CODE_TIME_SERVICE_62EF900A8F"], # 文宗 (甘露之变)
	[836, 841, "CODE_TIME_SERVICE_CE70CDD370", "CODE_TIME_SERVICE_62EF900A8F"],
	[841, 847, "CODE_TIME_SERVICE_94C832BD32", "CODE_TIME_SERVICE_62EF900A8F"], # 武宗 (会昌灭佛)
	[847, 860, "CODE_TIME_SERVICE_C035071BB3", "CODE_TIME_SERVICE_62EF900A8F"], # 宣宗 (大中之治)
	[860, 874, "CODE_TIME_SERVICE_14A8C51CF5", "CODE_TIME_SERVICE_62EF900A8F"], # 懿宗
	[874, 880, "CODE_TIME_SERVICE_DF16A52314", "CODE_TIME_SERVICE_62EF900A8F"], # 僖宗 (黄巢起义开始)
	[880, 881, "CODE_TIME_SERVICE_622C678144", "CODE_TIME_SERVICE_62EF900A8F"],
	[881, 885, "CODE_TIME_SERVICE_FB3F2583E0", "CODE_TIME_SERVICE_62EF900A8F"],
	[885, 888, "CODE_TIME_SERVICE_8DFE461005", "CODE_TIME_SERVICE_62EF900A8F"],
	[888, 889, "CODE_TIME_SERVICE_C01217EA48", "CODE_TIME_SERVICE_62EF900A8F"],
	# --- 终局：大厦将倾 ---
	[889, 890, "CODE_TIME_SERVICE_806479BBE5", "CODE_TIME_SERVICE_62EF900A8F"], # 昭宗
	[890, 892, "CODE_TIME_SERVICE_EBACEF51CD", "CODE_TIME_SERVICE_62EF900A8F"],
	[892, 894, "CODE_TIME_SERVICE_4CE22F0D8E", "CODE_TIME_SERVICE_62EF900A8F"],
	[894, 898, "CODE_TIME_SERVICE_EDEB19DEA2", "CODE_TIME_SERVICE_62EF900A8F"],
	[898, 901, "CODE_TIME_SERVICE_205BE8D289", "CODE_TIME_SERVICE_62EF900A8F"],
	[901, 904, "CODE_TIME_SERVICE_2B7437DCC3", "CODE_TIME_SERVICE_62EF900A8F"],
	[904, 907, "CODE_TIME_SERVICE_43283C362D", "CODE_TIME_SERVICE_62EF900A8F"]  # 哀帝 (907年被朱温篡位，大唐剧终)
]

# 1. 史书全卷 (Master Database)：只读，永远不删元素
# 结构: [{"time": 758.1, "callback": func1, "is_dynamic": false}]
var master_timeline: Array[Dictionary] = []

# 2. 待办清单 (Active Queue)：动态消耗，会被清空和重建
var event_queue: Array[Dictionary] = []

# 整数真理之源：累计经过的总天数（不再从浮点 year 反推，杜绝截断吞天）
var _total_days_elapsed: int:
	get: return GameSave.data.total_days_elapsed
	set(val): GameSave.data.total_days_elapsed = val
# tick 检查点：上一次 emit 时间信号时已经处理到的天数
var _tick_checkpoint: int:
	get: return GameSave.data.tick_checkpoint
	set(val): GameSave.data.tick_checkpoint = val

var current_day_of_year :int = 0
var current_xun := TranslationServer.translate("UI_TIME_CONTROL_PANEL_TEXT_2")
var current_day := 1
const DAYS_PER_YEAR: int = 360 # 标准化历法，一年 360 天，每月 30 天

# ── Tutorial 动态每旬天数 ──
var _days_per_xun_override: int = -1  # -1 = 使用默认值 10

## 返回当前每旬天数（tutorial 期间 2，正常 10）
func get_days_per_xun() -> int:
	#breakpoint
	return _days_per_xun_override if _days_per_xun_override > 0 else 10

## Tutorial 专用：设置每旬天数
func set_days_per_xun(days: int) -> void:
	_days_per_xun_override = days
	Logging.info("TimeService: days_per_xun override → %d" % days)

## Tutorial 专用：恢复默认每旬天数
func reset_days_per_xun() -> void:
	_days_per_xun_override = -1
	Logging.info("TimeService: days_per_xun override 已清除，恢复默认 10")

func _ready() -> void:
	EventBus.request_advance_time.connect(func(days):
		advance_time(days)
	)
	on_xun_tick.connect(func():
		Logging.info("Xun tick: %s" % current_xun))
	GameState.year = GameState.start_year
	_total_days_elapsed = int(GameState.year * DAYS_PER_YEAR)
	_tick_checkpoint = _total_days_elapsed
	current_day = _total_days_elapsed % get_days_per_xun()
	current_day_of_year = _total_days_elapsed % DAYS_PER_YEAR
	Logging.info("TimeService._ready: GameState.year set to %f, event_queue has %d items" % [GameState.year, event_queue.size()])
	if event_queue.size() > 0:
		Logging.info("  queue items: %s" % event_queue.map(func(e): return "{name:%s time:%f}" % [e.get("name","?"), e.time]))
	Engine.time_scale = 1
	pause()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return

	if not GameState:
		Logging.err("time_service: GameState autoload not ready in _process, skipping frame")
		return

	# 2. 检查浮点数队列 (你原有的逻辑)
	while not event_queue.is_empty() and GameState.year >= event_queue[0].time:
		var event = event_queue.pop_front()
		Logging.info("_process: FIRING event name='%s' time=%f at year=%f" % [event.get("name","?"), event.time, GameState.year])
		if event.callback.is_valid():
			pause_world(true) # 关键！触发事件时必须强制暂停游戏，防止弹窗地狱！
			event.callback.call()

	_emit_time_events()
	# current_day / current_day_of_year 在 _emit_time_events() 之后更新，
	# 确保与 _total_days_elapsed 同步（避免帧滞后显示上一帧的旧值）
	current_day = _total_days_elapsed % get_days_per_xun()
	current_day_of_year = _total_days_elapsed % DAYS_PER_YEAR


# --- 注册接口 ---
func register(trigger_time: float, function: Callable, name: String, epitaph_text: String = '', save_to_history: bool = true, entity: GameEntity = null):
	var event_data = {"time": trigger_time, "callback": function, "entity": entity, "name": name, "epitaph_text": epitaph_text}
	
	Logging.info("TimeService.register: name='%s' trigger_time=%f GameState.year=%f added_to_queue=%s" % [name, trigger_time, GameState.year, str(trigger_time >= GameState.year)])
	
	# 动态事件（比如信使移动）只需进当前队列；剧本事件需要进史书
	if save_to_history:
		master_timeline.append(event_data)
		# 史书不需要每时每刻排序，只在重建时排序即可，但保险起见：
		master_timeline.sort_custom(func(a, b): return a.time < b.time)
	
	# 如果事件发生在未来，塞进当前待办
	if trigger_time >= GameState.year:
		event_queue.append(event_data)
		event_queue.sort_custom(func(a, b): return a.time < b.time)
		future_event_registered.emit(event_data)
		Logging.info("  → event_queue is now: %s" % str(event_queue.map(func(e): return "{name:%s time:%f}" % [e.get("name","?"), e.time])))

func register_to_master_timeline(time: float, name: String, epitaph_text: String = ''):
	"""
	注册一个仅保存事件和名称的历史事件
	"""
	Logging.info("Registering event to master timeline: %s at year %s" % [name, time])
	var placeholder = func(): Logging.err("function for registed event data only for master timeline is not done yet!")
	var event_data = {"time": time, "name": name, "epitaph_text": epitaph_text, "function": placeholder, "entity": null}
	master_timeline.append(event_data)
	master_timeline.sort_custom(func(a, b): return a.time < b.time)

# --- 修改 1：修正 jump_to ---
func jump_to(new_year: float):
	Logging.info("Time jumped to: %s" % new_year)
	GameState.year = new_year
	# 💀 极度重要：同步底层天数缓存，防止 _process 醒来后疯狂补帧！
	_total_days_elapsed = int(GameState.year * DAYS_PER_YEAR)
	_tick_checkpoint = _total_days_elapsed
	
	EventBus.year_changed.emit(GameState.year)
	GameState.ratio_time = clampf(remap(GameState.year, GameState.start_year, GameState.end_year, 0, 1), 0.0, 1.0)
	
	_rebuild_queue_from_master()


func jump_to_clean(new_year: float):
	"""
	干净跳转：设置年份、同步天数、更新 ratio，清空 event_queue（不重建队列）。
	适合调试场景，跳转后不会触发任何历史事件回调。
	"""
	Logging.info("Clean jump to: %s — event queue wiped, nothing will fire" % new_year)
	GameState.year = new_year
	# 💀 极度重要：同步底层天数缓存，防止 _process 醒来后疯狂补帧！
	_total_days_elapsed = int(GameState.year * DAYS_PER_YEAR)
	_tick_checkpoint = _total_days_elapsed

	EventBus.year_changed.emit(GameState.year)
	GameState.ratio_time = clampf(remap(GameState.year, GameState.start_year, GameState.end_year, 0, 1), 0.0, 1.0)

	# 🗑️ 核弹级清空待办：不重建队列，不触发任何事件
	event_queue.clear()
	Logging.info("Clean jump: event queue cleared, %d events in master timeline preserved" % master_timeline.size())


# --- 修改 2：整数驱动时间推进，GameState.year 变为派生值 ---
func advance_time(days_to_add: int):
		#breakpoint
	Logging.info("[time] 时间跃迁，推进 %d 天..." % days_to_add)
	
	# 1. 真理之源：整数加法，绝不使用浮点
	_total_days_elapsed += days_to_add
	
	# 2. GameState.year 从整数天数派生
	GameState.year = _total_days_elapsed / float(DAYS_PER_YEAR)
	EventBus.year_changed.emit(GameState.year)
	GameState.ratio_time = clampf(remap(GameState.year, GameState.start_year, GameState.end_year, 0, 1), 0.0, 1.0)
	
	# 3. 发射所有跨越的时间信号
	_emit_time_events()
	
	# 4. 同步 current_day / current_day_of_year（不再等 _process 下一个帧才更新）
	current_day = _total_days_elapsed % get_days_per_xun()
	current_day_of_year = _total_days_elapsed % DAYS_PER_YEAR

func _emit_time_events():
	# 从整数真理之源计算需要发射的天
	if _total_days_elapsed > _tick_checkpoint:
		var days_passed = _total_days_elapsed - _tick_checkpoint
		for i in range(days_passed):
			var simulation_day = _tick_checkpoint + i + 1
			var day_of_month = (simulation_day % 30)
			
			var dp_xun := get_days_per_xun()
			if day_of_month == dp_xun - 1 or day_of_month == 2 * dp_xun - 1 or day_of_month == 3 * dp_xun - 1:
				on_xun_tick.emit()
				current_xun = get_xun_text(day_of_month)
			if day_of_month == 29:
				on_month_tick.emit()
				
			# 季节 tick：每90天（3个月）触发一次
			if simulation_day % 89 == 0:
				on_season_tick.emit()
				
			# 年份 tick：每360天触发一次
			if simulation_day % 359 == 0:
				on_year_tick.emit()
				
		# 💀 极度重要：完事后必须对齐标记！
		_tick_checkpoint = _total_days_elapsed
	
	# 3. 检查是否有队列事件被越过！
	_check_event_queue()

func _rebuild_queue_from_master():
	event_queue.clear() # 1. 撕毁当前待办清单
	
	# 2. 从史书中抄录未来
	for event in master_timeline:
		if event.time >= GameState.year:
			event_queue.append(event)
			
	# 3. 重新排序 (其实如果 master 是有序的，这一步甚至可以省掉，但为了防御性编程，排一下不亏)
	event_queue.sort_custom(func(a, b): return a.time < b.time)
	Logging.info("Queue rebuilt. Pending events: %d" % event_queue.size())
	
func play():
	set_process(true) # 开启 _process
	resume_world()
	time_start = true

func pause():
	set_process(false)
	time_start = false
	EventBus.speed_changed.emit(-1)

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
	var era_text = TranslationServer.translate("CODE_TIME_SERVICE_A00C2A7703")
	for era in ERA_TABLE:
		if year >= era[0] and year <= era[1]:
			var era_year_num = year - era[0] + 1
			var num_str: String
			if TranslationServer.get_locale() == "zh":
				num_str = _get_chinese_number(era_year_num)
			else:
				num_str = str(era_year_num)
			
			# 拼装：比如 "天宝 十四 载" — 翻译延迟到访问时
			era_text = "%s %s %s" % [TranslationServer.translate(era[2]), num_str, TranslationServer.translate(era[3])]
			break
	return era_text

# 一个简单的数字转中文辅助函数（1-99够用了）
func _get_chinese_number(num: int) -> String:
	if num == 1: return TranslationServer.translate("CODE_TIME_SERVICE_7F77F23AF7") # 第一年永远叫元年/元载
	
	var digits = ["", TranslationServer.translate("CODE_TIME_SERVICE_51A75F4634"), TranslationServer.translate("CODE_TIME_SERVICE_084B42F6E9"), TranslationServer.translate("CODE_TIME_SERVICE_A4C3313DEB"), TranslationServer.translate("CODE_TIME_SERVICE_754A9D5828"), TranslationServer.translate("CODE_TIME_SERVICE_C9B87F516A"), TranslationServer.translate("CODE_TIME_SERVICE_DE07B53838"), TranslationServer.translate("CODE_TIME_SERVICE_1B0542878C"), TranslationServer.translate("CODE_TIME_SERVICE_2C467D3673"), TranslationServer.translate("CODE_TIME_SERVICE_DF897DA6E0"), TranslationServer.translate("CODE_TIME_SERVICE_FC7EDD399A")]
	if num <= 10: return digits[num]
	if num < 20: return TranslationServer.translate("CODE_TIME_SERVICE_FC7EDD399A") + digits[num % 10]
	
	var tens = num / 10.0
	var ones = num % 10
	var res = digits[int(tens)] + TranslationServer.translate("CODE_TIME_SERVICE_FC7EDD399A")
	if ones > 0: res += digits[ones]
	return res


# 抽离出来的队列检查方法（复用你原本 _process 里的逻辑）
func _check_event_queue():
	while not event_queue.is_empty() and GameState.year >= event_queue[0].time:
		var event = event_queue.pop_front()
		if event.callback.is_valid():
			Logging.info("触发历史待办事件！设定时间: %f" % event.time)
			event.callback.call()

## 返回从当前天数到下一个 xun 边界 (day 9/19/29) 所需的天数。
## 当前已在边界上时返回 10（走到下一个）。在 29 时额外处理，返回 10 而非 0。
func get_days_to_next_xun() -> int:
	var day_of_month: int = _total_days_elapsed % 30
	var dp_xun := get_days_per_xun()
	# xun boundaries at day (dp_xun-1), (2*dp_xun-1), (3*dp_xun-1)
	var b1 := dp_xun - 1
	var b2 := 2 * dp_xun - 1
	var b3 := 3 * dp_xun - 1
	if day_of_month < b1:
		return b1 - day_of_month
	elif day_of_month < b2:
		return b2 - day_of_month
	elif day_of_month < b3:
		return b3 - day_of_month
	else:
		# day >= b3: 走到下个月的 day b1
		return (30 + b1) - day_of_month


func get_xun_text(day: int) -> String:
	var dp_xun := get_days_per_xun()
	# xun boundaries at day (dp_xun-1), (2*dp_xun-1), (3*dp_xun-1)
	var b1 := dp_xun - 1
	var b2 := 2 * dp_xun - 1
	var b3 := 3 * dp_xun - 1
	if day == b2:
		return TranslationServer.translate("CODE_TIME_SERVICE_FEAEC3E70D")
	elif day == b3:
		return TranslationServer.translate("CODE_TIME_SERVICE_475BAB9FD8")
	else:
		return TranslationServer.translate("UI_TIME_CONTROL_PANEL_TEXT_2")

func get_master_timeline() -> Array:
	"""
	排除时间 < 开始时间
	时间 > 当前时间的事件
	"""
	var result = []
	for event in master_timeline:
		if event.time >= GameState.start_year and event.time <= GameState.year:
			result.append(event)
	return result
