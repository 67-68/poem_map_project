extends Node

# ── 属性显示顺序（11个属性） ──────────────────────
const PROP_DISPLAY_ORDER: Array[int] = [
	ENUMS.PROPS.MONEY,
	ENUMS.PROPS.HEALTH,
	ENUMS.PROPS.FATIGUE,
	ENUMS.PROPS.BURNOUT,
	ENUMS.PROPS.DRUNK,
	ENUMS.PROPS.SICK,
	ENUMS.PROPS.INSPIRATION,
	ENUMS.PROPS.TALENT,
	ENUMS.PROPS.LITERARY_FAME,
	ENUMS.PROPS.OFFICIAL_PRESTIGE,
	ENUMS.PROPS.CAREER_PROGRESS,
]

# ── 属性中文简称映射 ─────────────────────────────
const PROP_SHORT_NAMES: Dictionary = {
	ENUMS.PROPS.MONEY: "钱",
	ENUMS.PROPS.HEALTH: "健",
	ENUMS.PROPS.FATIGUE: "疲",
	ENUMS.PROPS.BURNOUT: "烬",
	ENUMS.PROPS.DRUNK: "醉",
	ENUMS.PROPS.SICK: "疾",
	ENUMS.PROPS.INSPIRATION: "灵感",
	ENUMS.PROPS.TALENT: "才",
	ENUMS.PROPS.LITERARY_FAME: "名",
	ENUMS.PROPS.OFFICIAL_PRESTIGE: "望",
	ENUMS.PROPS.CAREER_PROGRESS: "仕",
}

# ── 上月末11属性快照 ──────────────────────────────
var _last_snapshot: Dictionary = {}

func _ready() -> void:
	Logging.info("[MonthEndSettlement] 月末结算系统就绪，连接 on_month_tick")
	if not TimeService.on_month_tick.is_connected(_on_month_tick):
		TimeService.on_month_tick.connect(_on_month_tick)
	_last_snapshot = _capture_current()

func _on_month_tick() -> void:
	Logging.info("[MonthEndSettlement] on_month_tick 触发")

	# 1. 获取当前11属性值
	var current := _capture_current()

	# 2. 如果 _last_snapshot 为空（首月）：保存快照后直接返回，不弹结算面板
	if _last_snapshot.is_empty():
		Logging.info("[MonthEndSettlement] 首月结算，仅保存快照，不展示结算面板")
		_last_snapshot = current
		return

	# 3. 计算 deltas
	var deltas := _compute_deltas(current, _last_snapshot)

	# 4. 构造 BaseEvent
	var event := _build_settlement_event(current, deltas)

	# 5. 推送到 NarrativeOverlay 栈顶，打断当前操作
	EventBus.push_event.emit(event, {"is_settlement": true})
	Logging.info("[MonthEndSettlement] 月末结算事件已推入栈顶，含 %d 个选项" % event.options.size())

	# 6. 保存本月快照（作为下次比较的基准）
	_last_snapshot = current

func _capture_current() -> Dictionary:
	var snap := {}
	for prop in PROP_DISPLAY_ORDER:
		snap[prop] = PlayerState.get_stat_val(prop)
	Logging.info("[MonthEndSettlement] 快照已捕获：%s" % snap)
	return snap

func _compute_deltas(current: Dictionary, last: Dictionary) -> Dictionary:
	var deltas := {}
	for prop in PROP_DISPLAY_ORDER:
		deltas[prop] = current[prop] - last[prop]
	Logging.info("[MonthEndSettlement] deltas 计算完成：%s" % deltas)
	return deltas

# ── 将 delta 转为圆圈符号串（不带颜色标签） ──────
func _delta_to_circles(delta: int) -> String:
	# 四舍五入到最近的10
	var abs_rounded: int = roundi(abs(delta) / 10.0) * 10

	if abs_rounded == 0:
		return "─"

	var full_count: int = abs_rounded / 20       # 满圆数量（每个●代表20）
	var has_half: bool = (abs_rounded % 20) >= 10 # 是否有半圆（◗代表10）

	var result := ""
	for _i in range(full_count):
		result += "●"
	if has_half:
		result += "◗"

	return result

# ── 将属性变化转为单行 BBcode ─────────────────────
func _delta_to_bbcode(prop_enum: int, delta: int) -> String:
	var short_name: String = PROP_SHORT_NAMES.get(prop_enum, "?")
	var circles: String = _delta_to_circles(delta)

	var color: String
	if delta > 0:
		color = "darkred"
	elif delta < 0:
		color = "#555"
	else:
		color = "gray"

	return "[%s] [color=%s]%s[/color]" % [short_name, color, circles]

# ── 获取年号+季节文本 ────────────────────────────
func _get_era_season_text() -> String:
	var day_of_year: int = TimeService._last_total_days % 360
	var season_index: int = day_of_year / 90          # 0春 1夏 2秋 3冬
	var month_in_season: int = (day_of_year % 90) / 30  # 0孟 1仲 2季

	var season_names := ["春", "夏", "秋", "冬"]
	var month_prefix := ["孟", "仲", "季"]

	var season_str: String = month_prefix[month_in_season] + season_names[season_index]

	var year_int: int = int(TimeService._last_total_days / 360)
	var era_text := TimeService.get_era_text(year_int)

	return "%s·%s 结" % [era_text, season_str]

# ── 构造结算 BaseEvent ───────────────────────────
func _build_settlement_event(_current: Dictionary, deltas: Dictionary) -> BaseEvent:
	var event := BaseEvent.new()

	# ── event.name ──
	var era_season := _get_era_season_text()
	event.name = "---- %s ----" % era_season

	# ── event.description：完整四段式 BBcode ──
	var lines: PackedStringArray = []

	# 第一段：标题
	lines.append("[center][font_size=22]---- %s ----[/font_size][/center]" % era_season)
	lines.append("")

	# 第二段：「长安米贵」— 11行属性变化
	lines.append("[font_size=16][b]「长安米贵」[/b][/font_size]")
	if _all_deltas_zero(deltas):
		lines.append("[i]本月诸般光景，与上月无异[/i]")
	else:
		for prop in PROP_DISPLAY_ORDER:
			lines.append(_delta_to_bbcode(prop, deltas[prop]))
	lines.append("")

	# 第三段：「状态衰变」
	lines.append("[font_size=16][b]「状态衰变」[/b][/font_size]")
	lines.append("[i]天道盈亏，自有定数。月盈则亏，水满则溢。[/i]")
	lines.append("")

	# 第四段：「潜伏暗线」
	lines.append("[font_size=16][b]「潜伏暗线」[/b][/font_size]")
	lines.append("[i]天机未显，静待时变。[/i]")

	event.description = "\n".join(lines)

	# ── event.options：唯一选项 "合上考评" ──
	var option := EventOption.new()
	option.description = "合上考评"
	# choice_result 为空（null），不做任何操作
	# requirement 为空，任何情况下都能选
	event.options = [option] as Array[BaseOption]

	Logging.info("[MonthEndSettlement] 结算事件已构造：%s" % event.name)
	return event


func _all_deltas_zero(deltas: Dictionary) -> bool:
	for prop in PROP_DISPLAY_ORDER:
		if roundi(abs(deltas[prop]) / 10.0) * 10 != 0:
			return false
	return true
