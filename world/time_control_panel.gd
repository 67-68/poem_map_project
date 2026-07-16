extends MarginContainer

const TOTAL_SLOTS: int = 5

@onready var label_era: Label = $HBox/Label_Era
@onready var label_greg: Label = $HBox/HBox2/Label_Gregorian
@onready var label_xun = $HBox/HBox2/Label_Xun
@onready var label_day: Label = $HBox/HBox2/Label_Day
@onready var label_time_left: Label = $HBox/HBox2/TimeLeft
@onready var time_texture = $HBox/TimeTexture

# 缓存上一帧的 current_day，用于 _process 轮询检测变化
var _last_known_day: int = -1

# ════════════════════════════════════════════════════════════
# 静态工具方法（可被 GUT 直接测试，无需场景树）
# ════════════════════════════════════════════════════════════


## 将剩余天数格式化为 5 字符的圆点串。
## ● = 2天, ◐ = 1天, ○ = 0天
## 防御性兜底: time_val 不在 [0, total_days] 时返回全白圆。
static func format_time_dots(time_val: int, total_days: int, display_slots: int = -1) -> String:
	if time_val < 0 or time_val > total_days:
		Logging.err('[time] 当前天数为 %d, total_days=%d, 为什么这个会出现?' % [time_val, total_days])
		return 'NaN'
	
	# 动态计算槽数：每 2 天一个槽，向上取整
	if display_slots < 0:
		display_slots = ceili(float(total_days) / 2.0)
	
	var black: int = time_val / 2
	var half: int = time_val % 2
	var white: int = display_slots - black - half
	
	var parts: Array[String] = []
	for _i in range(black):
		parts.append("●")
	if half:
		parts.append("◐")
	for _i in range(white):
		parts.append("○")
	return "".join(parts)


func _ready():
	# 始终保持暂停，不自动推进时间
	TimeService.pause()
	
	# 监听时间流动
	EventBus.year_changed.connect(_on_year_changed)
	TimeService.on_xun_tick.connect(func():
		label_xun.text = TimeService.current_xun
		_refresh_day_label()
		Logging.info('[time] xun tick: %s, day: %d' % [TimeService.current_xun, TimeService.current_day])
	)
	TimeService.on_xun_tick.connect(func():
		$UISoundComponent._on_click()
	)
	
	# 监听 time 属性变更，刷新剩余时间圆点和当前旬内天数
	PlayerState.player_stat_changed.connect(func(prop_name: String):
		if prop_name == "time":
			_refresh_time_left()
			_refresh_day_label()
	)
	PlayerState.player_stat_changed.connect(func(prop_name: String):
		time_texture.modulate = Color.WHITE.lerp(Color.DARK_RED, float(TimeService.current_day) / 10.0)
	)
	_refresh_time_left()
	_refresh_day_label()
	_last_known_day = TimeService.current_day

## 每帧轮询 current_day 变化，确保任何时间变动都能刷新。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var today: int = TimeService.current_day
	if PlayerState.get_stat_val('time') == 0:
		_on_link_button_pressed()
		
	if today != _last_known_day:
		_last_known_day = today
		_refresh_day_label()

func _refresh_time_left() -> void:
	var time_val: int = int(PlayerState.get_stat_val("time"))
	var total_days: int = SurvivalManager.get_current_ap_cap()
	label_time_left.text = "%d(%s)" % [time_val, format_time_dots(time_val, total_days)]

## 刷新当前是旬内第几天的显示。
## TimeService.current_day 是 0-based (0~9)，显示为 1-based "第X天"。
## 与 NPCDocument.appear_days (同样 0-based) 对应。
func _refresh_day_label() -> void:
	var day_zero_based: int = TimeService.current_day
	label_day.text = "第%d天" % (day_zero_based + 1)

## 🆕 强制刷新所有时间显示（年份/年号/旬/天）。
func refresh() -> void:
	var year: float = GameState.year if GameState else 735.0
	_on_year_changed(year)
	label_xun.text = TimeService.current_xun
	_refresh_day_label()
	_refresh_time_left()
	Logging.info("TimeControlPanel.refresh: year=%.1f era='%s' xun='%s' day=%d" % [
		year, label_era.text, label_xun.text, TimeService.current_day
	])

func _on_year_changed(current_float_year: float):
	var current_year = int(floor(current_float_year))
	# 比如 755.5 -> 0.5 * 12 + 1 = 7月
	var current_month = int(floor((current_float_year - current_year) * 12.0)) + 1
	
	# 1. 更新公元小字 (直白，功能性)
	label_greg.text = "公元 %d 年 %d 月" % [current_year, current_month]
	
	# 2. 查表计算大唐年号 (氛围，沉浸感)
	label_era.text = TimeService.get_era_text(current_year)

## 点击一次推进到下一个 xun 边界（例：day 3 → day 9；day 12 → day 19）。
## 不再递归；每次点击执行一次精准跳跃。
func _on_link_button_pressed() -> void:
	var days: int = TimeService.get_days_to_next_xun()
	Logging.info('[time] jump %d days to next xun' % days)
	TimeService.advance_time(days)
		
