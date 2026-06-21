class_name SmoothScrollContainer extends ScrollContainer
## 纸带阻尼滚动基类 — 接管滚轮 + 鼠标拖拽 + 键盘翻页
##
## 核心机制：
##   _process: 用 lerpf 逼近 target_scroll（仅在非拖拽状态）
##   _gui_input: 滚轮 → 调 target_scroll；左键拖拽 → 直接改值（"手指死死按住纸"）
##   scroll_page(): PgUp/PgDn 入口（由 InputManager 调用）

@export var scroll_speed: float = 120.0    # 滚轮每次步长 (像素)
@export var pan_sensitivity: float = 0.05  # 触控板灵敏度系数 (相对 scroll_speed 的阻尼，越小越迟钝)
@export var smooth_weight: float = 15.0    # 插值系数 (越小惯性越大, 越大越干脆)
@export var drag_friction: float = 1.0     # 拖拽摩擦力 (1.0=跟手, 0.5=纸很重扯不动)

var target_scroll: float = 0.0
var is_dragging: bool = false
var _frame_counter: int = 0  # DEBUG: 帧计数器，用于追踪 lerp 行为


func _ready() -> void:
	target_scroll = scroll_vertical
	Logging.info("SmoothScrollContainer[%s]: _ready scroll_vertical=%.1f max=%d page=%d" % [
		name, scroll_vertical,
		get_v_scroll_bar().max_value, get_v_scroll_bar().page
	])
	_style_scrollbar()


## 将原生滚动条压至极细枯褐色，不破坏纸带朱红边框契约
func _style_scrollbar() -> void:
	var vs := get_v_scroll_bar()
	if not vs:
		return

	# 宽度压至 4px
	vs.custom_minimum_size.x = 4

	# 轨道透明（消灭灰色背景）
	var track := StyleBoxFlat.new()
	track.bg_color = Color.TRANSPARENT
	vs.add_theme_stylebox_override(&"scroll", track)

	# 滑块：枯褐色半透明，圆角
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.30, 0.20, 0.12, 0.35)
	grabber.corner_radius_top_left = 2
	grabber.corner_radius_top_right = 2
	grabber.corner_radius_bottom_left = 2
	grabber.corner_radius_bottom_right = 2
	vs.add_theme_stylebox_override(&"grabber", grabber)
	vs.add_theme_stylebox_override(&"grabber_highlight", grabber)
	vs.add_theme_stylebox_override(&"grabber_pressed", grabber)

	# 去除滚动条与内容间的缝隙
	add_theme_constant_override(&"scroll_bar_separation", 0)


func _process(delta: float) -> void:
	var sv = scroll_vertical
	var ts = target_scroll
	var vs = get_v_scroll_bar()
	var max_val = vs.max_value
	var page = vs.page
	var max_scroll = max(0.0, max_val - page)
	
	# DEBUG: 每 60 帧打一条摘要日志，追踪 scroll_vertical vs target_scroll 的漂移
	_frame_counter += 1
	#if _frame_counter % 60 == 0:
	#	Logging.debug("SmoothScrollContainer[%s]: frame=%d sv=%.1f target=%.1f delta=%+.2f max=%.1f page=%.1f dragging=%s lerp_factor=%.3f" % [
	#		name, _frame_counter, sv, ts, sv - ts, max_val, page, is_dragging, smooth_weight * delta
	#	])
	
	# 没有在用手死死拽着纸时，才允许惯性滑动生效
	if not is_dragging and abs(sv - ts) > 1.0:
		var prev_sv = sv
		scroll_vertical = lerpf(sv, ts, smooth_weight * delta)
		# DEBUG: 如果 lerp 后 scroll_vertical 没有朝 target 方向移动，或者被回弹了，记录异常
		var new_sv = scroll_vertical
		if abs(new_sv - ts) >= abs(prev_sv - ts) and abs(prev_sv - ts) > 2.0:
			Logging.warn("SmoothScrollContainer[%s]: LERP_STALL sv %.1f->%.1f target=%.1f (no progress or regression)" % [name, prev_sv, new_sv, ts])
	elif not is_dragging and abs(sv - ts) <= 1.0 and sv != ts:
		scroll_vertical = ts  # snap to target
		Logging.debug("SmoothScrollContainer[%s]: SNAP sv=%.1f -> target=%.1f" % [name, sv, ts])


# ═══════════════════════════════════════════════
# _input — 拖拽事件捕获器（绕过子控件 mouse_filter 阻止）
# _input 先于 _gui_input 触发，不受子控件 MOUSE_FILTER_STOP 影响
# 子控件（Button/Label）会消费左键事件阻止冒泡，所以拖拽必须在 _input 层处理
# ═══════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	# ── 拖拽开始：左键按下，且鼠标在本控件范围内 ──
	# ⚠️ 不 accept_event()！否则子 Button 收不到点击，按钮将不可交互
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _mouse_inside():
			is_dragging = true
			target_scroll = scroll_vertical
			Logging.debug("SmoothScrollContainer[%s]: DRAG_START(via_input) sv=%.1f target=%.1f" % [name, scroll_vertical, target_scroll])
		return
	
	# ── 拖拽滑动：鼠标移动，且处于拖拽状态（全局追踪，即使鼠标移出控件）──
	if event is InputEventMouseMotion and is_dragging:
		var v_scrollbar = get_v_scroll_bar()
		var max_scroll = max(0.0, v_scrollbar.max_value - v_scrollbar.page)
		var pull_delta = -(event.relative.y * drag_friction)
		var prev_target = target_scroll
		target_scroll = clamp(target_scroll + pull_delta, 0.0, max_scroll)
		scroll_vertical = target_scroll
		accept_event()
		if _frame_counter % 10 == 0:
			Logging.debug("SmoothScrollContainer[%s]: DRAG_MOVE(via_input) rel.y=%.1f pull=%.1f target %.1f->%.1f sv=%.1f" % [name, event.relative.y, pull_delta, prev_target, target_scroll, scroll_vertical])
		return
	
	# ── 拖拽结束：左键释放（全局追踪）──
	# ⚠️ 不 accept_event()！释放事件仍需穿透到子 Button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			is_dragging = false
			Logging.debug("SmoothScrollContainer[%s]: DRAG_END(via_input) sv=%.1f target=%.1f" % [name, scroll_vertical, target_scroll])
		return


func _mouse_inside() -> bool:
	var global_rect = get_global_rect()
	return global_rect.has_point(get_global_mouse_position())


# ═══════════════════════════════════════════════
# _gui_input — 滚轮 + PanGesture（拖拽已迁移至 _input）
# 子控件（EventBtn 等）先收到事件；只有未被消费的事件才到这里
# accept_event() 阻止原生 ScrollContainer 接管
# ═══════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	var v_scrollbar = get_v_scroll_bar()
	# 防御：内容少于容器时 max_scroll 可能为负，clamp 到 >= 0
	var max_scroll = max(0.0, v_scrollbar.max_value - v_scrollbar.page)

	# ── 轨道 0：触控板/Magic Mouse PanGesture（macOS 主力输入）──
	if event is InputEventPanGesture:
		var prev_target = target_scroll
		# delta.y: 正值=向下滚动内容, 负值=向上
		# pan_sensitivity 阻尼系数：0.35 默认值提供足够阻力，避免触控板飞得太快
		target_scroll = clamp(target_scroll + event.delta.y * scroll_speed * pan_sensitivity, 0.0, max_scroll)
		Logging.debug("SmoothScrollContainer[%s]: PAN_GESTURE delta=%.2f pan_sens=%.2f target %.1f -> %.1f sv=%.1f max=%.1f" % [name, event.delta.y, pan_sensitivity, prev_target, target_scroll, scroll_vertical, max_scroll])
		# 强制同步 sv 到 target，避免原生 ScrollContainer 和 lerp 之间打架（lag back 根因）
		scroll_vertical = target_scroll
		accept_event()
		return  # 不再落入 GM-level 的事件捕获

	# ── 轨道 1：滚轮阅读流（平滑惯性）──
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var prev_target = target_scroll
			target_scroll = max(target_scroll - scroll_speed, 0.0)
			Logging.debug("SmoothScrollContainer[%s]: WHEEL_UP target %.1f -> %.1f sv=%.1f max=%.1f" % [name, prev_target, target_scroll, scroll_vertical, max_scroll])
			# 只改 target，_process 做 lerp；accept_event 阻止原生 ScrollContainer
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var prev_target = target_scroll
			target_scroll = min(target_scroll + scroll_speed, max_scroll)
			Logging.debug("SmoothScrollContainer[%s]: WHEEL_DOWN target %.1f -> %.1f sv=%.1f max=%.1f" % [name, prev_target, target_scroll, scroll_vertical, max_scroll])
			accept_event()
		else:
			# DEBUG: 其他鼠标按钮按下（如右键/中键），记录看看是否有意外输入
			Logging.debug("SmoothScrollContainer[%s]: OTHER_BTN_DOWN button=%d pressed=%s" % [name, event.button_index, event.pressed])

	# DEBUG: 记录所有未被上面分支匹配的事件类型
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventPanGesture):
		Logging.debug("SmoothScrollContainer[%s]: UNHANDLED_EVENT class=%s" % [name, event.get_class()])


# ═══════════════════════════════════════════════
# InputManager 桥接 — 键盘翻页 (PgUp/PgDn)
# ═══════════════════════════════════════════════

func scroll_page(direction: int) -> void:
	"""由 InputManager 调用。direction: -1=向上, +1=向下"""
	var v_scrollbar = get_v_scroll_bar()
	var max_scroll = v_scrollbar.max_value - v_scrollbar.page
	target_scroll = clamp(target_scroll + direction * v_scrollbar.page * 0.8, 0.0, max_scroll)
	is_dragging = false  # 确保 _process 接管 lerp 惯性
