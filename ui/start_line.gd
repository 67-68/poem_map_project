# [Contract: Hover-Triggered Route Line]
# 入口场景的「京」标签 hover 时，以 Bézier 曲线绘制路线，线段从起点延伸到终点。
# 曲线中点在两端点之间随机 jitter（±jitter_range px），每次 hover 重新随机。
# hover 时线立即可见（alpha=1），线段在 enter_duration 内从起点生长到终点（ease-in-out）。
# mouse leave 时 alpha 淡出消失。
extends Line2D

# ── 导出配置 ─────────────────────────────────────────────

## 触发 hover 的 UI 节点（PanelContainer "京"）
@export var trigger_node: Control

## 起点（绝对坐标）
@export var start_point: Vector2 = Vector2(665, 240)

## 终点（绝对坐标）
@export var end_point: Vector2 = Vector2(560, 310)

## 线生长动画时长（秒）
@export var enter_duration: float = 2.0

## 线消失动画时长（秒）
@export var exit_duration: float = 0.5

## jitter 范围（px），中点 x/y 各独立随机 ± 此值
@export var jitter_range: float = 30.0

## 线宽
@export var line_width: float = 3.0

## Bézier 曲线采样点数（越高曲线越平滑）
@export var curve_sample_count: int = 64

# ── 枚举 ─────────────────────────────────────────────────

enum State { IDLE, ENTERING, VISIBLE, EXITING }

# ── 内部状态 ─────────────────────────────────────────────

var _state: State = State.IDLE
var _active_tween: Tween
var _is_hovering: bool = false
var _full_points: PackedVector2Array   # 完整 Bézier 采样点（缓存）
var _draw_progress: float = 0.0        # 0.0 ~ 1.0，当前绘制进度

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	width = line_width
	modulate.a = 0.0
	clear_points()

	# fallback: export NodePath 在直接加载场景时可能解析失败
	if not trigger_node:
		trigger_node = get_node_or_null("../Control/PanelContainer")

	if trigger_node:
		trigger_node.mouse_entered.connect(_on_trigger_mouse_entered)
		trigger_node.mouse_exited.connect(_on_trigger_mouse_exited)
		Logging.info("start_line: 已绑定 trigger_node=%s, start=(%.0f,%.0f) end=(%.0f,%.0f)" % [
			trigger_node.name, start_point.x, start_point.y, end_point.x, end_point.y
		])
	else:
		Logging.err("start_line: trigger_node 未找到！请检查场景结构")

func _exit_tree() -> void:
	_kill_tween()
	if trigger_node and is_instance_valid(trigger_node):
		trigger_node.mouse_entered.disconnect(_on_trigger_mouse_entered)
		trigger_node.mouse_exited.disconnect(_on_trigger_mouse_exited)

# ── 鼠标事件 ─────────────────────────────────────────────

func _on_trigger_mouse_entered() -> void:
	Logging.info("start_line: mouse_entered trigger, state=%d" % _state)
	_is_hovering = true

	match _state:
		State.IDLE:
			_generate_full_curve()
			_play_enter_tween()
		State.EXITING:
			_kill_tween()
			_generate_full_curve()
			_play_enter_tween()
		State.VISIBLE:
			pass
		State.ENTERING:
			pass

func _on_trigger_mouse_exited() -> void:
	Logging.info("start_line: mouse_exited trigger, state=%d" % _state)
	_is_hovering = false

	match _state:
		State.ENTERING, State.VISIBLE:
			_play_exit_tween()
		State.IDLE, State.EXITING:
			pass

# ── 曲线生成 ──────────────────────────────────────────────

func _generate_full_curve() -> void:
	var raw_mid: Vector2 = (start_point + end_point) / 2.0
	var jx: float = randf_range(0.0, jitter_range)
	var jy: float = randf_range(0.0, jitter_range)
	var mid: Vector2 = Vector2(raw_mid.x + jx, raw_mid.y + jy)

	Logging.info("start_line: midpoint raw=(%.0f,%.0f) jittered=(%.0f,%.0f) jitter=(%.0f,%.0f)" % [
		raw_mid.x, raw_mid.y, mid.x, mid.y, jx, jy
	])

	# 采样二次 Bézier：B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
	_full_points = PackedVector2Array()
	for i in range(curve_sample_count + 1):
		var t: float = float(i) / curve_sample_count
		var u: float = 1.0 - t
		var bx: float = u * u * start_point.x + 2.0 * u * t * mid.x + t * t * end_point.x
		var by: float = u * u * start_point.y + 2.0 * u * t * mid.y + t * t * end_point.y
		_full_points.append(Vector2(bx, by))

	Logging.info("start_line: Bézier 完整曲线已采样 %d 点" % _full_points.size())

# ── 线段生长核心 ──────────────────────────────────────────

## 由 tween_method 回调，t 从 0→1，逐帧更新可见线段
func _set_draw_progress(t: float) -> void:
	_draw_progress = t
	if _full_points.is_empty():
		return
	var visible_count: int = maxi(2, int(t * (curve_sample_count + 1)))
	# 取前 visible_count 个点作为当前可见线段
	var visible: PackedVector2Array = PackedVector2Array()
	for i in range(visible_count):
		visible.append(_full_points[i])
	self.points = visible

# ── Tween 动画 ────────────────────────────────────────────

func _play_enter_tween() -> void:
	_kill_tween()

	# 初始：线段为空（但 alpha 立即可见，width 固定）
	modulate = Color.WHITE
	modulate.a = 1.0
	_draw_progress = 0.0
	self.points = PackedVector2Array()

	Logging.info("start_line: enter tween started, draw_progress 0→1, duration=%.1fs" % enter_duration)

	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_method(_set_draw_progress, 0.0, 1.0, enter_duration)
	_active_tween.tween_callback(_on_enter_tween_finished)

func _play_exit_tween() -> void:
	_kill_tween()

	Logging.info("start_line: exit tween started, alpha 1→0, duration=%.1fs" % exit_duration)

	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(self, "modulate:a", 0.0, exit_duration)
	_active_tween.tween_callback(_on_exit_tween_finished)

func _on_enter_tween_finished() -> void:
	Logging.info("start_line: enter tween finished, draw_progress=%.2f" % _draw_progress)
	_active_tween = null
	_state = State.VISIBLE
	if not _is_hovering:
		Logging.info("start_line: 生长完成时用户已离开，立即退出")
		_play_exit_tween()

func _on_exit_tween_finished() -> void:
	Logging.info("start_line: exit tween finished")
	_active_tween = null
	_state = State.IDLE
	clear_points()
	_full_points.clear()
	_draw_progress = 0.0
	modulate.a = 0.0
	Logging.info("start_line: 已回到 IDLE")

# ── 工具函数 ──────────────────────────────────────────────

func _kill_tween() -> void:
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
