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
@onready var _time_breath: CanvasLayer = $UI/TimeBreathUI
@onready var _poem_creation: Node = $UI/PoemCreation
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
var _tape_was_visible: bool

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

	# ── 注册 ambient profile ──
	_register_ambient_profiles()

	# ── Tab 键盘切换纯地图模式（由 InputManager 发出）──
	if not EventBus.has_signal("request_toggle_map_only"):
		Logging.err("Main: EventBus 缺少 signal request_toggle_map_only，请在 eventbus.gd 中添加")
	else:
		EventBus.request_toggle_map_only.connect(_on_toggle_map_only)
		Logging.info("Main: 已连接 EventBus.request_toggle_map_only")

	# ── 游戏结束 → 切换到独立墓碑场景 ──
	if not EventBus.has_signal("show_tombstone_screen"):
		Logging.err("Main: EventBus 缺少 signal show_tombstone_screen，请在 eventbus.gd 中添加")
	else:
		EventBus.show_tombstone_screen.connect(_on_game_over)
		Logging.info("Main: 已连接 EventBus.show_tombstone_screen -> _on_game_over")

	# ── 隐藏结局继续游戏检测：tomb_stone_screen 设置 flag 后切换到此场景 ──
	call_deferred("_check_hidden_ending_continue")


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

	# ── 纯地图模式下任意键 → 退出（ESC/Tab 除外，由 InputManager 接管）──
	if _is_map_only and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
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

	# ── 记录 NarrativeOverlay 进入前的可见性 ──
	_tape_was_visible = _narrative_overlay.visible
	Logging.info("Main: NarrativeOverlay 进入前 visible=%s" % _tape_was_visible)

	# ── NarrativeOverlay → 往上推出（委托 TapeVisualizer）──
	_narrative_overlay.play_exit_animation(SLIDE_DURATION)

	# ── 动画完成后隐藏节点 + 隐藏其他 UI ──
	_tween_exit.chain().tween_callback(func():
		_left_panel.visible = false
		_right_panel.visible = false
		# _narrative_overlay.visible 由 TapeVisualizer.play_exit_to_top 内部管理
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

	# 恢复 NarrativeOverlay 进入前的可见性（原本不可见就不恢复）
	if _tape_was_visible:
		_narrative_overlay.play_enter_animation(SLIDE_DURATION)
		Logging.info("Main: 恢复 NarrativeOverlay 可见性（委托 TapeVisualizer）")
	else:
		Logging.info("Main: NarrativeOverlay 原本不可见，不恢复")
	_restore_visibility()

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

	_tween_enter.chain().tween_callback(func():
		Logging.info("Main: 纯地图模式退出动画完成")
	)


	Logging.info("Main: _exit_map_only 动画完成")


# ═══════════════════════════════════════════════
# 公共 API — 面板滑出/滑入（供 PoemCreationPage 调用）
# ═══════════════════════════════════════════════

## 左右面板向外滑出（复用纯地图模式的滑动动画）。
## 不改变 _is_map_only 状态，不隐藏其他 UI。
func slide_panels_out() -> void:
	Logging.info("Main: slide_panels_out 开始")
	_kill_all_tweens()
	_record_positions()

	_tween_exit = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_exit.set_parallel(true)

	var left_width := _left_panel.size.x
	_tween_exit.tween_property(_left_panel, "position:x", _left_original_x - left_width - 50.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_exit.tween_property(_left_panel, "modulate:a", 0.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var right_width := _right_panel.size.x
	_tween_exit.tween_property(_right_panel, "position:x", _right_original_x + right_width + 50.0, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_exit.tween_property(_right_panel, "modulate:a", 0.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_exit.chain().tween_callback(func():
		_left_panel.visible = false
		_right_panel.visible = false
		Logging.info("Main: slide_panels_out 动画完成")
	)


## 左右面板从外侧滑回原位。
func slide_panels_in() -> void:
	Logging.info("Main: slide_panels_in 开始")
	_kill_all_tweens()

	_left_panel.visible = true
	_right_panel.visible = true

	var left_width := _left_panel.size.x
	var right_width := _right_panel.size.x

	_tween_enter = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_enter.set_parallel(true)

	_tween_enter.tween_property(_left_panel, "position:x", _left_original_x, SLIDE_DURATION) \
		.from(_left_original_x - left_width - 50.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_enter.tween_property(_left_panel, "modulate:a", 1.0, FADE_DURATION) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_enter.tween_property(_right_panel, "position:x", _right_original_x, SLIDE_DURATION) \
		.from(_right_original_x + right_width + 50.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_enter.tween_property(_right_panel, "modulate:a", 1.0, FADE_DURATION) \
		.from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_enter.chain().tween_callback(func():
		Logging.info("Main: slide_panels_in 动画完成")
	)


# ═══════════════════════════════════════════════
# Tab 键盘 toggle（由 InputManager 触发）
# ═══════════════════════════════════════════════

func _on_toggle_map_only() -> void:
	Logging.info("Main: Tab → toggle 纯地图模式（当前=%s）" % _is_map_only)
	if _is_map_only:
		_exit_map_only()
	else:
		_record_positions()
		_enter_map_only()



# ======================================================
# 可见性保存/恢复/隐藏
# ======================================================

func _save_visibility():
	_other_ui_nodes = [
		_ambition_hud, _simple_toast, _debug_info,
		_time_breath, _poem_creation, _social_wall,
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


# ======================================================
# 工具
# ======================================================

func _register_ambient_profiles() -> void:
	const LOW_WIND = preload("res://assets/sounds/755_backhome/low_wind.ogg")
	const HARSH_WIND = preload("res://assets/sounds/755_backhome/harsh_wind.ogg")

	AudioManager.register_ambient_profile("755_backhome", [
		{
			"streams": [LOW_WIND],
			"volume_db": 0.0,
			"replay_gap": 0.0,
		},
		{
			"streams": [HARSH_WIND],
			"volume_db": -8.0,
			"replay_gap": 25.0,
			"replay_gap_max": 30.0,
		},
	])
	Logging.info("Main: 已注册 ambient profile → 755_backhome")

	# ── 注册 AmbientMusic profile ──
	const DRONE1 = preload("res://assets/sounds/backgrounds/drones/drone1.ogg")
	const DRONE2 = preload("res://assets/sounds/backgrounds/drones/drone2.ogg")
	const DRONE3 = preload("res://assets/sounds/backgrounds/drones/drone3.ogg")
	const DRONE4 = preload("res://assets/sounds/backgrounds/drones/drone4.ogg")
	AudioManager.register_ambient_music_profile("drones", [DRONE1, DRONE2, DRONE3, DRONE4], 30.0, 90.0)
	Logging.info("Main: 已注册 ambient music profile → drones (4 首, music_volume_ratio=%.2f)" % GameSave.data.music_volume_ratio)

	# ── 启动 AmbientMusic（5s 后渐入播放第一首，之后曲终静默 30-90s 循环）──
	AudioManager.set_ambient_music_profile("drones")


func _on_game_over(death_hint: String) -> void:
	Logging.info("Main: 游戏结束 signal 收到，切换到独立墓碑场景")
	_kill_all_tweens()
	GameState.death_cause = death_hint
	call_deferred("_do_change_to_tombstone")


func _do_change_to_tombstone() -> void:
	Logging.info("Main: 执行场景切换 -> res://ui/tomb_stone_screen.tscn")
	var tree := get_tree()
	if not tree:
		Logging.err("Main: get_tree() 为 null，无法切换场景")
		return
	tree.change_scene_to_file("res://ui/tomb_stone_screen.tscn")


# ═══════════════════════════════════════════════
# 隐藏结局继续游戏
# ═══════════════════════════════════════════════

func _check_hidden_ending_continue() -> void:
	if not GameState.pending_hidden_ending_continue:
		Logging.info("Main._check_hidden_ending_continue: pending_hidden_ending_continue=false，正常启动")
		return
	
	Logging.info("Main._check_hidden_ending_continue: 检测到隐藏结局继续信号，启动过场流程")
	# 消耗 flag，防止重复触发
	GameState.pending_hidden_ending_continue = false
	
	# 等一下让场景完全就绪（CinematicOverlay 节点需要 ready）
	await get_tree().process_frame
	await get_tree().process_frame
	
	_start_hidden_ending_continue()


func _start_hidden_ending_continue() -> void:
	Logging.info("Main._start_hidden_ending_continue: 开始隐藏结局继续过场")
	
	var cinematic_node: CinematicOverlay = _cinematic_overlay
	if not cinematic_node:
		Logging.err("Main._start_hidden_ending_continue: CinematicOverlay 节点不存在！跳过过场直接入队事件")
		_queue_get_official_event()
		return
	
	var texts: Array[String] = [
		"这么久过去了，那点俗物早就花光了。",
		"你在三大礼赋之后，对官场彻底失去了信心。",
		"也罢，不如暂时收起那些经世济民的念想，先养家糊口吧…",
		"……",
	]
	
	Logging.info("Main._start_hidden_ending_continue: 播放 cinematic 过场，%d 段文字" % texts.size())
	
	# 连接 finished 信号（如果还没连接）
	if not cinematic_node.finished.is_connected(_on_hidden_ending_cinematic_finished):
		cinematic_node.finished.connect(_on_hidden_ending_cinematic_finished, CONNECT_ONE_SHOT)
	
	EventBus.cinematic_start.emit(texts, {})


func _on_hidden_ending_cinematic_finished() -> void:
	Logging.info("Main._on_hidden_ending_cinematic_finished: 过场结束，排队 event_get_official")
	_queue_get_official_event()


func _queue_get_official_event() -> void:
	Logging.info("Main._queue_get_official_event: 使用 QueueEventOperator 排队 event_get_official")
	var op := QueueEventOperator.new()
	op.event_key = "event_get_official"
	# QueueEventOperator 依赖于 _captured_context，需要在 init 中捕获
	op._captured_context = {}
	op.operate()
	Logging.info("Main._queue_get_official_event: 已发射 request_event_key → event_get_official")


func _kill_all_tweens() -> void:
	if _tween_exit:
		_tween_exit.kill()
		_tween_exit = null
	if _tween_enter:
		_tween_enter.kill()
		_tween_enter = null
