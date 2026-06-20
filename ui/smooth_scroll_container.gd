class_name SmoothScrollContainer extends ScrollContainer
## 纸带阻尼滚动基类 — 接管滚轮 + 鼠标拖拽 + 键盘翻页
##
## 核心机制：
##   _process: 用 lerpf 逼近 target_scroll（仅在非拖拽状态）
##   _gui_input: 滚轮 → 调 target_scroll；左键拖拽 → 直接改值（"手指死死按住纸"）
##   scroll_page(): PgUp/PgDn 入口（由 InputManager 调用）

@export var scroll_speed: float = 120.0    # 滚轮每次步长 (像素)
@export var smooth_weight: float = 15.0    # 插值系数 (越小惯性越大, 越大越干脆)
@export var drag_friction: float = 1.0     # 拖拽摩擦力 (1.0=跟手, 0.5=纸很重扯不动)

var target_scroll: float = 0.0
var is_dragging: bool = false


func _ready() -> void:
	target_scroll = scroll_vertical


func _process(delta: float) -> void:
	# 没有在用手死死拽着纸时，才允许惯性滑动生效
	if not is_dragging and scroll_vertical != target_scroll:
		scroll_vertical = lerpf(scroll_vertical, target_scroll, smooth_weight * delta)
		if abs(scroll_vertical - target_scroll) < 1.0:
			scroll_vertical = target_scroll


func _gui_input(event: InputEvent) -> void:
	var v_scrollbar = get_v_scroll_bar()
	var max_scroll = v_scrollbar.max_value - v_scrollbar.page

	# ── 轨道 1：滚轮阅读流（平滑惯性）──
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_scroll = max(target_scroll - scroll_speed, 0.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_scroll = min(target_scroll + scroll_speed, max_scroll)
			accept_event()

	# ── 轨道 2：物理触觉流（暴力拉扯）──
	# 1. 抓取与松开
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true       # 死死按住纸张
			target_scroll = scroll_vertical  # 打断任何正在进行的惯性
		else:
			is_dragging = false      # 松开手，让 _process 接管惯性

	# 2. 摩擦力拖拽
	if event is InputEventMouseMotion and is_dragging:
		# event.relative.y 是鼠标移动的像素差
		# 鼠标往上提 (-y)，纸带往下走 (+scroll)，所以要减去它
		var pull_delta = -(event.relative.y * drag_friction)
		target_scroll = clamp(target_scroll + pull_delta, 0.0, max_scroll)
		# 拖拽时直接修改数值，不用 lerp！
		# 这产生"手死死按在纸上，纸绝对跟手"的粗糙物理摩擦感
		scroll_vertical = target_scroll
		accept_event()


# ═══════════════════════════════════════════════
# InputManager 桥接 — 键盘翻页 (PgUp/PgDn)
# ═══════════════════════════════════════════════

func scroll_page(direction: int) -> void:
	"""由 InputManager 调用。direction: -1=向上, +1=向下"""
	var v_scrollbar = get_v_scroll_bar()
	var max_scroll = v_scrollbar.max_value - v_scrollbar.page
	target_scroll = clamp(target_scroll + direction * v_scrollbar.page * 0.8, 0.0, max_scroll)
	is_dragging = false  # 确保 _process 接管 lerp 惯性
