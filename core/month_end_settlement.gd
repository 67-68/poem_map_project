extends Node
const _BaseEvent = preload("res://model/event.gd")
const _BaseOption = preload("res://model/event/base_option.gd")
const _ChoiceResult = preload("res://model/choice_result.gd")
const _EventOption = preload("res://model/event/event_option.gd")
const _NarrativeOverlay = preload("res://characters/narrative_overlay.gd")
const _PopEventOperator = preload("res://core/operators/pop_event_operator.gd")

# ── 属性显示顺序（11个属性） ──────────────────────
const PROP_DISPLAY_ORDER: Array[int] = [
	ENUMS.PROPS.MONEY,
	ENUMS.PROPS.HEALTH,
	ENUMS.PROPS.PRESTIGE,
	ENUMS.PROPS.TALENT,
	ENUMS.PROPS.PROGRESS,
	ENUMS.PROPS.TIME,
	ENUMS.PROPS.ASTUTENESS,
	ENUMS.PROPS.COMPOSURE,
	ENUMS.PROPS.INSPIRATION,
	ENUMS.PROPS.MOMENTUM,
]

# ── 属性中文简称映射 ─────────────────────────────
const PROP_SHORT_NAMES: Dictionary = {
	ENUMS.PROPS.MONEY: "钱",
	ENUMS.PROPS.HEALTH: "健",
	ENUMS.PROPS.PRESTIGE: "名",
	ENUMS.PROPS.TALENT: "才",
	ENUMS.PROPS.PROGRESS: "途",
	ENUMS.PROPS.TIME: "时",
	ENUMS.PROPS.ASTUTENESS: "府",
	ENUMS.PROPS.COMPOSURE: "定",
	ENUMS.PROPS.INSPIRATION: "兴",
	ENUMS.PROPS.MOMENTUM: "势",
}

# ── 上月末11属性快照 ──────────────────────────────
var _last_snapshot: Dictionary = {}

@export var _left_panel_path: NodePath
var _left_panel: Node:
	get():
		if not _left_panel:
			get_left_panel()
		return _left_panel

func _ready() -> void:
	Logging.info("[MonthEndSettlement] 月末结算系统就绪，连接 on_month_tick")
	if not TimeService.on_month_tick.is_connected(_on_month_tick):
		TimeService.on_month_tick.connect(_on_month_tick)
	_last_snapshot = _capture_current()

	# 连接 player_stat_changed 信号用于属性变化颜色覆盖
	if not PlayerState.player_stat_changed.is_connected(_on_stat_changed_for_color):
		PlayerState.player_stat_changed.connect(_on_stat_changed_for_color)

	# 每旬清空染色（比月初清空粒度更细）
	if not TimeService.on_xun_tick.is_connected(_on_xun_color_reset):
		TimeService.on_xun_tick.connect(_on_xun_color_reset)

	# 解析 _left_panel
	get_left_panel()
	Logging.info("[MonthEndSettlement] _left_panel 解析结果：%s" % (_left_panel != null))

func get_left_panel():
	Logging.info('month end settlement: trying to get left panel')
	if not _left_panel_path.is_empty():
		_left_panel = get_node(_left_panel_path)
	else:
		_left_panel = get_tree().root.get_node("Main/UI/Margin/HBox/LeftPanel")

func _on_month_tick() -> void:
	if TutorialController.is_tutorial_active():
		Logging.info('month end settlement: tutorial active, not on month tick')
		return

	# 月初刷新时清空所有属性颜色覆盖
	if _left_panel != null:
		_left_panel.reset_all_prop_colors()

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

# ── 每旬初清空染色 ────────────────────────────────
func _on_xun_color_reset() -> void:
	if TutorialController.is_tutorial_active():
		Logging.info('month end settlement: tutorial active, not on xun tick')
		return
	"""每旬结算开始时清空所有属性颜色覆盖，使染色仅反映当旬变化。"""
	if _left_panel != null:
		_left_panel.reset_all_prop_colors()
	Logging.info("[MonthEndSettlement] 旬初已清空所有属性颜色覆盖")

# ── 根据 stat_name 查找快照中对应属性的值 ──────────
func _get_snapshot_value_for_stat(stat_name: String) -> int:
	for prop in PROP_DISPLAY_ORDER:
		var prop_str: String = ENUMS.to_prop_str(prop)
		if prop_str == stat_name:
			return _last_snapshot.get(prop, 0)
	return 0

# ── player_stat_changed 回调：属性变化时实时染色 ──
func _on_stat_changed_for_color(stat_name: String) -> void:
	if TutorialController.is_tutorial_active():
		Logging.info('month end settlement: tutorial active, not paint color')
		return

	if _last_snapshot.is_empty():
		return  # 首月不染色

	if _left_panel == null:
		return

	var displayed_keys: Array = _left_panel.get_displayed_prop_keys()
	if not stat_name in displayed_keys:
		return

	var current: int = PlayerState.get_stat_val(stat_name)
	var snapshot: int = _get_snapshot_value_for_stat(stat_name)

	if current > snapshot:
		_left_panel.set_prop_label_color(stat_name, Color("#79B08D"))
		Logging.info("[MonthEndSettlement] %s 增长染色 (current=%d, snapshot=%d)" % [stat_name, current, snapshot])
	elif current < snapshot:
		_left_panel.set_prop_label_color(stat_name, Color("#C92B2A"))
		Logging.info("[MonthEndSettlement] %s 衰减染色 (current=%d, snapshot=%d)" % [stat_name, current, snapshot])
	else:
		_left_panel.reset_prop_label_color(stat_name)
		Logging.info("[MonthEndSettlement] %s 恢复默认色 (current=%d, snapshot=%d)" % [stat_name, current, snapshot])

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
	var delta_str: String = ("%+d" % delta) if delta != 0 else " 0"

	var color: String
	if delta > 0:
		color = "darkred"
	elif delta < 0:
		color = "#555"
	else:
		color = "gray"

	return "[%s] %s [color=%s]%s[/color]" % [short_name, delta_str, color, circles]

# ── 获取年号+季节文本 ────────────────────────────
func _get_era_season_text() -> String:
	var day_of_year: int = TimeService._total_days_elapsed % 360
	var season_index: int = day_of_year / 90          # 0春 1夏 2秋 3冬
	var month_in_season: int = (day_of_year % 90) / 30  # 0孟 1仲 2季

	var season_names := ["春", "夏", "秋", "冬"]
	var month_prefix := ["孟", "仲", "季"]

	var season_str: String = month_prefix[month_in_season] + season_names[season_index]

	var year_int: int = int(TimeService._total_days_elapsed / 360)
	var era_text := TimeService.get_era_text(year_int)

	return "%s·%s 结" % [era_text, season_str]

# ── 构造结算 BaseEvent ───────────────────────────
func _build_settlement_event(_current: Dictionary, deltas: Dictionary) -> BaseEvent:
	var event := BaseEvent.new()

	# ── event.name ──
	var era_season := _get_era_season_text()
	event.name = "---- %s ----" % era_season

	# ── event.description：三段式 BBcode（标题由 _title_label 独立渲染）──
	var lines: PackedStringArray = []

	# 第一段：「长安米贵」— 11行属性变化
	lines.append("[font_size=16][b]「长安米贵」[/b][/font_size]")
	if _all_deltas_zero(deltas):
		lines.append("[i]本月诸般光景，与上月无异[/i]")
	else:
		for prop in PROP_DISPLAY_ORDER:
			if deltas[prop] == 0:
				continue
			lines.append(_delta_to_bbcode(prop, deltas[prop]))
	lines.append("")

	# 第二段：「状态衰变」
	lines.append("[font_size=16][b]「状态衰变」[/b][/font_size]")
	lines.append("[i]天道盈亏，自有定数。月盈则亏，水满则溢。[/i]")
	lines.append("")

	# 第三段：「潜伏暗线」
	lines.append("[font_size=16][b]「潜伏暗线」[/b][/font_size]")
	lines.append("[i]天机未显，静待时变。[/i]")

	event.description = "\n".join(lines)

	# ── event.options：唯一选项 "合上考评" ──
	var option := EventOption.new()
	option.description = "合上考评"

	var result := ChoiceResult.new()
	var pop_op := PopEventOperator.new()
	result.operators = [pop_op]
	option.choice_result = result

	event.options = [option] as Array[BaseOption]

	Logging.info("[MonthEndSettlement] 结算事件已构造：%s" % event.name)
	return event


func _all_deltas_zero(deltas: Dictionary) -> bool:
	for prop in PROP_DISPLAY_ORDER:
		if roundi(abs(deltas[prop]) / 10.0) * 10 != 0:
			return false
	return true
