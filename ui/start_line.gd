# [Contract: Hover-Triggered Route Line — 多 Trigger 复用]
# 单条 Line2D 支持多个 hover trigger 节点，由外部（main_page.gd）调用 bind_triggers() 注入。
# 曲线中点在两端点之间随机 jitter（仅右下方向），每次 hover 重新随机。
# hover 时线立即可见（alpha=1），线段在 enter_duration 内从起点生长到终点（ease-in-out）。
# mouse leave 时 alpha 淡出消失。
extends Line2D

# ── 导出配置 ─────────────────────────────────────────────

@export var enter_duration: float = 2.0
@export var exit_duration: float = 0.5
@export var jitter_range: float = 30.0
@export var line_width: float = 3.0
@export var curve_sample_count: int = 64

# ── 枚举 ─────────────────────────────────────────────────

enum State { IDLE, ENTERING, VISIBLE, EXITING }

# ── 内部状态 ─────────────────────────────────────────────

var _state: State = State.IDLE
var _active_tween: Tween
var _is_hovering: bool = false
var _current_trigger_index: int = -1
var _full_points: PackedVector2Array
var _draw_progress: float = 0.0

## 运行时配置：[[trigger_control, start_point, end_point], ...]
var _configs: Array = []

# ── 公开 API（由外部脚本调用）────────────────────────────

## main_page.gd 调用此方法注入三组 trigger + 坐标
func bind_triggers(configs: Array) -> void:
	_configs = configs
	var names: PackedStringArray = PackedStringArray()
	for i in range(_configs.size()):
		var entry: Array = _configs[i]
		var tn: Control = entry[0] as Control
		if tn:
			tn.mouse_entered.connect(_on_trigger_entered.bind(i))
			tn.mouse_exited.connect(_on_trigger_exited)
			names.append(tn.name)
		else:
			names.append("MISSING[%d]" % i)
			Logging.err("start_line: bind_triggers[%d] trigger 为 null" % i)
	Logging.info("start_line: 已绑定 %d 个 trigger: [%s]" % [_configs.size(), ", ".join(names)])

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	width = line_width
	modulate.a = 0.0
	clear_points()

# ── 鼠标事件 ─────────────────────────────────────────────

func _on_trigger_entered(index: int) -> void:
	Logging.info("start_line: mouse_entered trigger[%d], state=%d" % [index, _state])
	_is_hovering = true

	if _current_trigger_index == index and (_state == State.VISIBLE or _state == State.ENTERING):
		return

	_kill_tween()
	_current_trigger_index = index
	_generate_full_curve()
	_play_enter_tween()

func _on_trigger_exited() -> void:
	Logging.info("start_line: mouse_exited, state=%d" % _state)
	_is_hovering = false

	match _state:
		State.ENTERING, State.VISIBLE:
			_play_exit_tween()
		State.IDLE, State.EXITING:
			pass

# ── 曲线生成 ──────────────────────────────────────────────

func _generate_full_curve() -> void:
	var entry: Array = _configs[_current_trigger_index]
	var sp: Vector2 = entry[1]
	var ep: Vector2 = entry[2]
	var raw_mid: Vector2 = (sp + ep) / 2.0
	var jx: float = randf_range(0.0, jitter_range)
	var jy: float = randf_range(0.0, jitter_range)
	var mid: Vector2 = Vector2(raw_mid.x + jx, raw_mid.y + jy)

	Logging.info("start_line: trigger[%d] sp=(%.0f,%.0f) ep=(%.0f,%.0f) jitter=(%.0f,%.0f)" % [
		_current_trigger_index, sp.x, sp.y, ep.x, ep.y, jx, jy
	])

	_full_points = PackedVector2Array()
	for i in range(curve_sample_count + 1):
		var t: float = float(i) / curve_sample_count
		var u: float = 1.0 - t
		var bx: float = u * u * sp.x + 2.0 * u * t * mid.x + t * t * ep.x
		var by: float = u * u * sp.y + 2.0 * u * t * mid.y + t * t * ep.y
		_full_points.append(Vector2(bx, by))

	Logging.info("start_line: Bézier 曲线已采样 %d 点" % _full_points.size())

# ── 线段生长核心 ──────────────────────────────────────────

func _set_draw_progress(t: float) -> void:
	_draw_progress = t
	if _full_points.is_empty():
		return
	var visible_count: int = maxi(2, int(t * (curve_sample_count + 1)))
	var visible: PackedVector2Array = PackedVector2Array()
	for i in range(visible_count):
		visible.append(_full_points[i])
	self.points = visible

# ── Tween 动画 ────────────────────────────────────────────

func _play_enter_tween() -> void:
	_state = State.ENTERING
	_kill_tween()

	modulate = Color.WHITE
	modulate.a = 1.0
	_draw_progress = 0.0
	self.points = PackedVector2Array()

	Logging.info("start_line: enter tween, draw 0→1, dur=%.1fs" % enter_duration)

	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_method(_set_draw_progress, 0.0, 1.0, enter_duration)
	_active_tween.tween_callback(_on_enter_tween_finished)

func _play_exit_tween() -> void:
	_state = State.EXITING
	_kill_tween()

	Logging.info("start_line: exit tween, alpha 1→0, dur=%.1fs" % exit_duration)

	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(self, "modulate:a", 0.0, exit_duration)
	_active_tween.tween_callback(_on_exit_tween_finished)

func _on_enter_tween_finished() -> void:
	_active_tween = null
	_state = State.VISIBLE
	if not _is_hovering:
		_play_exit_tween()

func _on_exit_tween_finished() -> void:
	_active_tween = null
	_state = State.IDLE
	_current_trigger_index = -1
	clear_points()
	_full_points.clear()
	_draw_progress = 0.0
	modulate.a = 0.0

# ── 工具函数 ──────────────────────────────────────────────

func _kill_tween() -> void:
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
