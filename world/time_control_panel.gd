extends MarginContainer

const TOTAL_DAYS: int = 10

@onready var label_era: Label = $HBox/Label_Era
@onready var label_greg: Label = $HBox/HBox2/Label_Gregorian
@onready var label_xun = $HBox/HBox2/Label_Xun
@onready var label_time_left: Label = $HBox/HBox2/TimeLeft
@onready var time_texture = $HBox/TimeTexture

func _ready():
	# 始终保持暂停，不自动推进时间
	TimeService.pause()
	
	# 监听时间流动
	EventBus.year_changed.connect(_on_year_changed)
	TimeService.on_xun_tick.connect(func():
		label_xun.text = TimeService.current_xun
	)
	
	# 监听 time 属性变更，刷新剩余时间圆点
	PlayerState.player_stat_changed.connect(func(prop_name: String):
		if prop_name == "time":
			_refresh_time_left()
	)
	_refresh_time_left()

func _refresh_time_left() -> void:
	var time_val: int = int(PlayerState.get_stat_val("time"))
	# 剩余天数 (0 ~ 10)，已消耗 = TOTAL_DAYS - time_val
	var consumed: int = max(0, TOTAL_DAYS - time_val)
	var remaining: int = max(0, time_val)
	
	var parts: Array[String] = []
	
	# 已消耗：空心圆 (○) 和半空心 (◑)
	var consumed_full: int = consumed / 2
	var consumed_half: bool = (consumed % 2) == 1
	for i in range(consumed_full):
		parts.append("○")
	if consumed_half:
		parts.append("◑")
	
	# 剩余：实心圆 (●) 和半实 (◐)
	var remaining_full: int = remaining / 2
	var remaining_half: bool = (remaining % 2) == 1
	for i in range(remaining_full):
		parts.append("●")
	if remaining_half:
		parts.append("◐")
	
	label_time_left.text = "".join(parts)

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
