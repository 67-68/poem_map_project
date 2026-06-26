extends MarginContainer

const TOTAL_DAYS: int = 10
const TOTAL_SLOTS: int = 5

@onready var label_era: Label = $HBox/Label_Era
@onready var label_greg: Label = $HBox/HBox2/Label_Gregorian
@onready var label_xun = $HBox/HBox2/Label_Xun
@onready var label_time_left: Label = $HBox/HBox2/TimeLeft
@onready var time_texture = $HBox/TimeTexture

# ════════════════════════════════════════════════════════════
# 静态工具方法（可被 GUT 直接测试，无需场景树）
# ════════════════════════════════════════════════════════════


## 将剩余天数格式化为 5 字符的圆点串。
## ● = 2天, ◐ = 1天, ○ = 0天
## 防御性兜底: time_val 不在 [0, total_days] 时返回全白圆。
static func format_time_dots(time_val: int, total_days: int = 10, total_slots: int = 5) -> String:
	if time_val < 0 or time_val > total_days:
		Logging.err('[time] 当前天数为 %s, 为什么这个会出现?' % time_val)
		return 'NaN'
	
	var black: int = time_val / 2
	var half: int = time_val % 2
	var white: int = total_slots - black - half
	
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
		Logging.info('[time] xun tick: %s' % TimeService.current_xun)
	)
	TimeService.on_xun_tick.connect(func():
		$UISoundComponent._on_click()
	)
	
	# 监听 time 属性变更，刷新剩余时间圆点
	PlayerState.player_stat_changed.connect(func(prop_name: String):
		if prop_name == "time":
			_refresh_time_left()
	)
	_refresh_time_left()

func _refresh_time_left() -> void:
	var time_val: int = int(PlayerState.get_stat_val("time"))
	label_time_left.text = format_time_dots(time_val)

func _on_year_changed(current_float_year: float):
	var current_year = int(floor(current_float_year))
	# 比如 755.5 -> 0.5 * 12 + 1 = 7月
	var current_month = int(floor((current_float_year - current_year) * 12.0)) + 1
	
	# 1. 更新公元小字 (直白，功能性)
	label_greg.text = "公元 %d 年 %d 月" % [current_year, current_month]
	
	# 2. 查表计算大唐年号 (氛围，沉浸感)
	label_era.text = TimeService.get_era_text(current_year)

func _process(_delta):
	time_texture.modulate = Color.WHITE.lerp(Color.DARK_RED, float(TimeService.current_day) / 10.0)

## 点击一次推进到下一个 xun 边界（例：day 3 → day 9；day 12 → day 19）。
## 不再递归；每次点击执行一次精准跳跃。
func _on_link_button_pressed() -> void:
	var days: int = TimeService.get_days_to_next_xun()
	Logging.info('[time] jump %d days to next xun' % days)
	TimeService.advance_time(days)
		

