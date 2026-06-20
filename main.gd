extends Node

## main.gd — 纯地图模式
## 在地图区域右键：左右面板往左右推出、NarrativeOverlay 往上推出，仅留地图
## 任意键（除 ESC）：所有 UI 滑回原位
##
## 鼠标穿透链：Margin(mouse_filter=IGNORE) → HBox →
##   LeftPanel(STOP) | spacer(IGNORE) | RightPanel(STOP)
## 右键落在左/右面板上被 STOP 拦截，只有落在 spacer 区域
## （即地图上方）的右键才能穿过 UI 到达 _unhandled_input。

# ── 节点引用 ──
@onready var _left_panel: PanelContainer = $UI/Margin/HBox/LeftPanel
@onready var _right_panel: PanelContainer = $UI/Margin/HBox/RightPanel
@onready var _narrative_overlay: PanelContainer = $TapeLayer/NarrativeOverlay

@onready var _ambition_hud: Node = $UI/AmbitionHUD
@onready var _simple_toast: Node = $UI/SimpleToast
@onready var _debug_info: Node = $UI/DebugInfo
@onready var _tomb_stone: Node = $UI/TombStoneScreen
@onready var _time_breath: CanvasLayer = $UI/TimeBreathUI
@onready var _poem_creation: Node = $UI/PoemCreation
@onready var _emotion_radar: ColorRect = $UI/EmotionRadar
@onready var _social_wall: Node = $UI/SocialWallPanel
@onready var _controller: Node = $UI/Controller
@onready var _picker_blur: ColorRect = $PickerBlurLayer/PickerBlurOverlay
@onready var _blur_overlay: ColorRect = $MapLayer/Worldroot/BlurOverlay
@onready var _cinematic_overlay: Node = $CinematicOverlay

# ── 状态 ──
var _is_map_only: bool = false
var _positions_recorded: bool = false

# 原始位置缓存
var _left_original_x: float
var _right_original_x: float
var _tape_original_y: float

# 其他 UI 节点的可见性备份
var _other_ui_nodes: Array[Node] = []
var _other_ui_visibility: Array[bool] = []

# Tween 引用
var _tween_exit: Tween
var _tween_enter: Tween

const SLIDE_DURATION: float = 0.65
const FADE_DURATION: float = 0.3


func _ready() -> void:
	Logging.info("Main: 纯地图模式脚本已就绪")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _record_positions() -> void:
	if _positions_recorded:
		return
	_positions_recorded = true
	_left_original_x = _left_panel.position.x
	_right_original_x = _right_panel.position.x
	_tape_original_y = _narrative_overlay.position.y
	Logging.info("Main: 记录原始位置 left.x=%.1f right.x=%.1f tape.y=%.1f" % [
		_left_original_x, _right_original_x, _tape_original_y
	])


func _unhandled_input(event: InputEvent) -> void:
	# ── 地图区域右键 → 进入纯地图模式 ──
	#     只有鼠标落在 spacer 区域（IGNORE）时才会到达这里
	#     落在 LeftPanel / RightPanel 被 STOP → 不会触发
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not _is_map_only:
			Logging.info("Main: 地图区域右键 → 进入纯地图模式")
			_record_positions()
			_enter_map_only()
		get_viewport().set_input_as_handled()
		return

	# ── 纯地图模式下任意键 → 退出 ──
	if _is_map_only and event is InputEventKey and event.pressed:
		# ESC 保留给原有暂停/退出逻辑，不拦截
		if event.keycode == KEY_ESCAPE:
			return
		Logging.info("Main: 按键 → 退出纯地图模式 (key=%s)" % event.keycode)
		_exit_map_only()
		get_viewport().set_input_as_handled()
		return


# ═══════════════════════════════════════════════
# 进入纯地图模式
# ═══════════════════════════════════════════════

func _enter_map_only() -> void:
	Logging.info("Main: ▶ 进入纯地图模式")
	_is_map_only = true

	_kill_all_tweens()
	_save_visibility()

	var viewport_h := get_viewport_rect().size.y

	_tween_exit = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_exit.set_parallel(true)

	# ── 左面板 → 往左推出（CUBIC+EASE_OUT，参考 NarrativeOverlay._show_tape 动画风格）──
	var left_width := _left_panel.size.x
	_tween_exit.tween_property(_left_panel, "position:x", _left_original_x - left_width - 50.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_exit.tween_property(_left_panel, "modulate:a", 0.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── 右面板 → 往右推出 ──
	var right_width := _right_panel.size.x
	_tween_exit.tween_property(_right_panel, "position:x", _right_original_x + right_width + 50.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_exit.tween_property(_right_panel, "modulate:a", 0.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── NarrativeOverlay → 往上推出（CUBIC+EASE_OUT，与 _show_tape 反向）──
	_tween_exit.tween_property(_narrative_overlay, "position:y", _tape_original_y - viewport_h, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_exit.tween_property(_narrative_overlay, "modulate:a", 0.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── 动画完成后隐藏节点 + 隐藏其他 UI ──
	_tween_exit.chain().tween_callback(func():
		_left_panel.visible = false
		_right_panel.visible = false
		_narrative_overlay.visible = false
		_hide_other_ui()
		Logging.info("Main: 纯地图模式动画完成 — 仅地图可见")
	)


# ═══════════════════════════════════════════════
# 退出纯地图模式
# ═══════════════════════════════════════════════

func _exit_map_only() -> void:
	Logging.info("Main: ◀ 退出纯地图模式")
	_is_map_only = false

	_kill_all_tweens()

	# 先恢复可见性，再播动画
	_left_panel.visible = true
	_right_panel.visible = true
	_narrative_overlay.visible = true
	_restore_visibility()

	var viewport_h := get_viewport_rect().size.y
	var left_width := _left_panel.size.x
	var right_width := _right_panel.size.x

	_tween_enter = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_enter.set_parallel(true)

	# ── 左面板 → 从左外滑回原位 ──
	_tween_enter.tween_property(_left_panel, "position:x", _left_original_x, SLIDE_DURATION) \
		.from(_left_original_x - left_width - 50.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_enter.tween_property(_left_panel, "modulate:a", 1.0, FADE_DURATION) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── 右面板 → 从右外滑回原位 ──
	_tween_enter.tween_property(_right_panel, "position:x", _right_original_x, SLIDE_DURATION) \
		.from(_right_original_x + right_width + 50.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_enter.tween_property(_right_panel, "modulate:a", 1.0, FADE_DURATION) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ── NarrativeOverlay → 从上外滑回原位 ──
	_tween_enter.tween_property(_narrative_overlay, "position:y", _tape_original_y, SLIDE_DURATION) \
		.from(_tape_original_y - viewport_h) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_enter.tween_property(_narrative_overlay, "modulate:a", 1.0, FADE_DURATION) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_enter.chain().tween_callback(func():
		Logging.info("Main: 纯地图模式退出动画完成")


# ═══════════════════════════════════════════════
# 可见性保存/恢复/隐藏
# ═══════════════════════════════════════════════

func _save_visibility() -> void:
	_other_ui_nodes = [
		_ambition_hud, _simple_toast, _debug_info, _tomb_stone,
		_time_breath, _poem_creation, _emotion_radar, _social_wall,
		_controller, _picker_blur, _blur_overlay, _cinematic_overlay,
	]
	_other_ui_visibility.clear()
	for node in _other_ui_nodes:
		_other_ui_visibility.append(node.visible)
	Logging.info("Main: 保存其他 UI 可见性状态")


func _hide_other_ui() -> void:
	for node in _other_ui_nodes:
		node.visible = false
	Logging.info("Main: 隐藏其他 UI 完成")


func _restore_visibility() -> void:
	for i in range(_other_ui_nodes.size()):
		_other_ui_nodes[i].visible = _other_ui_visibility[i]
	Logging.info("Main: 恢复其他 UI 可见性完成")


# ═══════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════

func _kill_all_tweens() -> void:
	if _tween_exit:
		_tween_exit.kill()
		_tween_exit = null
	if _tween_enter:
		_tween_enter.kill()
		_tween_enter = null
