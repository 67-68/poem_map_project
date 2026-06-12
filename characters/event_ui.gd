class_name EventUI extends TextureRect

signal option_selected(choice_result)


# ── 打字机参数 ──────────────────────────────────
## 打字机速度（秒/字），对应 story_arcs 要求的 20-30 字/秒 ≈ 0.04s/字
const SLOW_SPEED: float = 0.04
## SLOWEST 打字机速度（秒/字），慢一倍 ≈ 12 字/秒
const SLOWEST_SPEED: float = 0.08
## 阶段间停顿（秒）
const PHASE_PAUSE: float = 0.6


# ── 子节点引用 ──────────────────────────────────
@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _content_label: RichTextLabel = $Margin/VBox/ContentLabel
@onready var _example_label: RichTextLabel = $Margin/VBox/ExampleLabel
@onready var _option_btns: Control = $Margin/VBox/OptionBtns


# ── 打字机状态 ──────────────────────────────────
var _skip_requested: bool = false
var _current_timer: Timer = null


# ═══════════════════════════════════════════════
# 公共 API
# ═══════════════════════════════════════════════

## 清空所有 UI 内容，防止前一个事件的残留数据污染新事件
func _clear_all() -> void:
	Logging.info("EventUI._clear_all: 清空所有 UI 内容")
	texture = null
	_title_label.text = ""
	_content_label.text = ""
	_example_label.text = ""
	_option_btns.apply_btns([], func(r): pass)


## FAST 模式：瞬间填充所有 UI 元素（默认行为）
## 等价于 old NarrativeOverlay.apply_narrative() 的 484-495 行
func display_instant(event: BaseEvent, all_options: Array, context: Dictionary) -> void:
	Logging.info("EventUI.display_instant: FAST 模式填充事件 '%s'" % event.name)
	_clear_all()
	texture = event.icon
	_title_label.text = event.name
	_content_label.text = Util.tr_and_resolve(event.description, context, event)
	_example_label.text = event.example
	_show_options(all_options)


## SLOW / SLOWEST 模式：打字机逐阶段显示
## 显示顺序：title → description → example → option
## 用户左键点击可跳过当前阶段（填满文字后自动进入下一阶段）
## type_speed: 打字机速度（秒/字），默认 SLOW_SPEED，SLOWEST 模式传入 SLOWEST_SPEED
func display_slow(event: BaseEvent, all_options: Array, context: Dictionary, type_speed: float = SLOW_SPEED) -> void:
	Logging.info("EventUI.display_slow: 模式开始事件 '%s'（type_speed=%.3f）" % [event.name, type_speed])
	_clear_all()
	_skip_requested = false

	# Phase 1: Title
	Logging.debug("EventUI: Phase 1 — Title 打字机开始")
	await _typewrite_phase(_title_label, event.name, type_speed)
	Logging.debug("EventUI: Phase 1 — Title 完成")

	# Phase 2: Description（含 {@context_key} 模板插值）
	Logging.debug("EventUI: Phase 2 — Description 打字机开始")
	var desc: String = Util.tr_and_resolve(event.description, context, event)
	await _typewrite_phase(_content_label, desc, type_speed)
	Logging.debug("EventUI: Phase 2 — Description 完成")

	# Phase 3: Example（可选）
	if not event.example.is_empty():
		Logging.debug("EventUI: Phase 3 — Example 打字机开始")
		await _typewrite_phase(_example_label, event.example, type_speed)
		Logging.debug("EventUI: Phase 3 — Example 完成")
	else:
		Logging.debug("EventUI: Phase 3 — example 为空，跳过")

	# Phase 4: 显示选项
	Logging.info("EventUI: Phase 4 — 显示选项（%d 个）" % all_options.size())
	_show_options(all_options)
	Logging.info("EventUI.display_slow: 事件 '%s' 显示完成" % event.name)


# ═══════════════════════════════════════════════
# 打字机基础设施
# ═══════════════════════════════════════════════

## 执行一个打字机阶段（重置 skip 状态 → 打字机 → 阶段间停顿）
## type_speed: 打字机速度（秒/字），由 display_slow 传入
func _typewrite_phase(label: Control, full_text: String, type_speed: float = SLOW_SPEED) -> void:
	_skip_requested = false
	label.text = ""
	await _typewrite(label, full_text, type_speed)
	if _skip_requested:
		Logging.debug("EventUI: 阶段被用户跳过，进入短暂停留")
	else:
		Logging.debug("EventUI: 阶段自然播完，进入短暂停留")
	# 自然播完或 skip 后，短暂停留再进入下一阶段
	await _wait(PHASE_PAUSE)


## 逐字显示文本（字符级别）
## 检测到 _skip_requested 时立即填满全文并返回
func _typewrite(label: Control, full_text: String, speed: float) -> void:
	if speed <= 0.0 or full_text.is_empty():
		Logging.debug("EventUI._typewrite: speed=%f 或文本为空，直接填充" % speed)
		label.text = full_text
		return

	for i in range(full_text.length()):
		if _skip_requested:
			Logging.debug("EventUI._typewrite: 检测到 skip，填充全文（%d 字）" % full_text.length())
			label.text = full_text
			return
		label.text = full_text.left(i + 1)
		await _wait(speed)
		if _skip_requested:
			Logging.debug("EventUI._typewrite: wait 后检测到 skip，填充全文")
			label.text = full_text
			return


## 显示选项按钮，将 option_selected 信号桥接到 NarrativeOverlay
func _show_options(all_options: Array) -> void:
	Logging.info("EventUI._show_options: 桥接 %d 个选项到 option_selected 信号" % all_options.size())
	_option_btns.apply_btns(all_options, func(r):
		Logging.info("EventUI: 选项被选中，转发 option_selected 信号")
		option_selected.emit(r)
	)


## 不受世界暂停影响的等待定时器
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.start()
	_current_timer = timer
	await timer.timeout
	_current_timer = null
	timer.queue_free()


## 左键点击 → 跳过当前打字机阶段
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _skip_requested:
			Logging.debug("EventUI: 用户左键点击，跳过当前打字机阶段")
		_skip_requested = true
		if _current_timer:
			_current_timer.wait_time = 0.0
