## 高斯模糊管理器 — 可复用的模糊效果控制器
##
## 提供三种模糊模式：
##   1. 事件模糊:   在 MapLayer(-1) 和 UI(1) 之间插入 CanvasLayer(0)，模糊地图
##                  但不遮挡左右面板（面板在 UI layer=1，在模糊层之上）
##   2. Picker 模糊: Picker 激活时在 Layer 50 插入全屏毛玻璃
##                   TapeLayer (layer=100) 纸带悬浮其上，保持清晰
##   3. Cinematic:   创建独立 CanvasLayer (layer=100) 全屏模糊，覆盖一切
##
## 关键设计：
##   - 三种模糊必须使用独立于 MapLayer 的 CanvasLayer，
##     因为 Godot 4 的 hint_screen_texture 只能捕获当前 CanvasLayer 之前渲染的视口内容。
##   - 事件模糊与 Cinematic 后模糊分开：事件模糊夹在 Map 和 UI 之间（layer=0），
##     Cinematic 在最顶层（layer=100）。二者可同时存在互不干扰。
##
## 用法：
##   BlurManager.trigger_event_blur()    — 事件触发，模糊地图
##   BlurManager.return_to_hub()         — 纸带清空，清除地图模糊
##   BlurManager.show_picker_blur()      — Picker 展示，Layer 50 毛玻璃渐入
##   BlurManager.hide_picker_blur()      — Picker 完成，Layer 50 毛玻璃渐出

extends Node

const LOG_TAG := "BlurManager"

# ── 事件模糊：独立 CanvasLayer (layer=0)，夹在 Map 和 UI 之间 ──
var _event_blur_canvas_layer: CanvasLayer = null
var _event_blur_overlay: ColorRect = null
var _event_blur_mat: ShaderMaterial = null
var _event_blur_tween: Tween = null

# ── Picker 模糊（main.tscn 预建的 PickerBlurLayer (layer=50) → PickerBlurOverlay）
var _picker_blur_overlay: ColorRect = null
var _picker_blur_tween: Tween = null
var _picker_blur_located: bool = false

# ── 缓动参数 ─────────────────────────────────────────
const MAP_BLUR_IN_AMOUNT: float = 3.0
const MAP_BLUR_OUT_AMOUNT: float = 0.0
const MAP_DARKEN_IN_AMOUNT: float = 0.5
const MAP_DARKEN_OUT_AMOUNT: float = 0.0
const MAP_BLUR_IN_DURATION: float = 1.0
const MAP_BLUR_OUT_DURATION: float = 0.8

const PICKER_BLUR_AMOUNT: float = 3.5
const PICKER_DARKEN_AMOUNT: float = 0.5
const PICKER_BLUR_DURATION: float = 0.5

# ── Cinematic 过场后模糊 ──────────────────────────────
const CINEMATIC_POST_BLUR_AMOUNT: float = 5.0
const CINEMATIC_POST_DARKEN_AMOUNT: float = 0.0
const CINEMATIC_POST_FADE_IN: float = 0.8
const CINEMATIC_POST_FADE_OUT: float = 0.8

# ── CanvasLayer 层级 ──────────────────────────────────
# MapLayer=-1, EventBlur=0, UI=1, PickerBlur=50, TapeLayer=100, Cinematic=100
const EVENT_BLUR_LAYER: int = 0
const CINEMATIC_LAYER: int = 100


# ═══════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_ensure_picker_blur_overlay()
	Logging.info("%s: 延迟初始化完成，picker_blur=%s" % [
		LOG_TAG,
		"OK" if _picker_blur_overlay else "MISSING",
	])


# ═══════════════════════════════════════════════
# 事件模糊 CanvasLayer（layer=0，Map 之上 UI 之下）
# ═══════════════════════════════════════════════

func _ensure_event_blur_layer() -> bool:
	if _event_blur_canvas_layer and is_instance_valid(_event_blur_canvas_layer):
		return true

	Logging.info("%s: 创建事件模糊 CanvasLayer (layer=%d)" % [LOG_TAG, EVENT_BLUR_LAYER])

	var shader := load("res://shaders/blur_bg.gdshader") as Shader
	if not shader:
		Logging.err("%s: 无法加载 blur_bg.gdshader" % LOG_TAG)
		return false

	_event_blur_mat = ShaderMaterial.new()
	_event_blur_mat.shader = shader
	_event_blur_mat.set("shader_parameter/blur_amount", 0.0)
	_event_blur_mat.set("shader_parameter/darken_amount", 0.0)

	_event_blur_canvas_layer = CanvasLayer.new()
	_event_blur_canvas_layer.name = "EventBlurLayer"
	_event_blur_canvas_layer.layer = EVENT_BLUR_LAYER

	_event_blur_overlay = ColorRect.new()
	_event_blur_overlay.name = "EventBlurOverlay"
	_event_blur_overlay.material = _event_blur_mat
	_event_blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_event_blur_canvas_layer.add_child(_event_blur_overlay)
	get_tree().root.add_child(_event_blur_canvas_layer)

	_set_event_blur_fullscreen()

	if not get_tree().root.size_changed.is_connected(_set_event_blur_fullscreen):
		get_tree().root.size_changed.connect(_set_event_blur_fullscreen)

	Logging.info("%s: EventBlurLayer 创建完成, layer=%d, size=%s" % [
		LOG_TAG,
		_event_blur_canvas_layer.layer,
		_event_blur_overlay.size,
	])
	return true


func _set_event_blur_fullscreen() -> void:
	if not _event_blur_overlay or not is_instance_valid(_event_blur_overlay):
		return
	var vp_size := get_viewport().get_visible_rect().size
	_event_blur_overlay.position = Vector2.ZERO
	_event_blur_overlay.size = vp_size


func _kill_event_blur_tween() -> void:
	if _event_blur_tween and _event_blur_tween.is_valid():
		_event_blur_tween.kill()
	_event_blur_tween = null


# ═══════════════════════════════════════════════
# 公共 API — 事件模糊
# ═══════════════════════════════════════════════

## 事件触发：模糊地图 + 压暗（idempotent）
## BlurOverlay 在 layer=0，只覆盖 MapLayer(-1)，不遮挡 UI(1) 的左右面板
func trigger_event_blur() -> void:
	if not _ensure_event_blur_layer():
		return

	_kill_event_blur_tween()

	Logging.info("%s: 触发事件模糊 (blur=%.1f darken=%.1f, layer=%d)" % [
		LOG_TAG, MAP_BLUR_IN_AMOUNT, MAP_DARKEN_IN_AMOUNT, EVENT_BLUR_LAYER,
	])

	_event_blur_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_event_blur_tween.set_parallel(true)
	_event_blur_tween.tween_property(_event_blur_mat, "shader_parameter/blur_amount", MAP_BLUR_IN_AMOUNT, MAP_BLUR_IN_DURATION)
	_event_blur_tween.tween_property(_event_blur_mat, "shader_parameter/darken_amount", MAP_DARKEN_IN_AMOUNT, MAP_BLUR_IN_DURATION)


## 纸带清空：清除地图模糊，销毁事件模糊层
func return_to_hub() -> void:
	if not _event_blur_canvas_layer or not is_instance_valid(_event_blur_canvas_layer):
		return

	_kill_event_blur_tween()

	Logging.info("%s: 清除事件模糊" % LOG_TAG)

	_event_blur_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_event_blur_tween.set_parallel(true)
	_event_blur_tween.tween_property(_event_blur_mat, "shader_parameter/blur_amount", MAP_BLUR_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)
	_event_blur_tween.tween_property(_event_blur_mat, "shader_parameter/darken_amount", MAP_DARKEN_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)
	_event_blur_tween.finished.connect(_destroy_event_blur_layer, CONNECT_ONE_SHOT)


func _destroy_event_blur_layer() -> void:
	if _event_blur_canvas_layer and is_instance_valid(_event_blur_canvas_layer):
		if get_tree() and get_tree().root.size_changed.is_connected(_set_event_blur_fullscreen):
			get_tree().root.size_changed.disconnect(_set_event_blur_fullscreen)
		_event_blur_canvas_layer.queue_free()
		Logging.info("%s: EventBlurLayer 已销毁" % LOG_TAG)
	_event_blur_canvas_layer = null
	_event_blur_overlay = null
	_event_blur_mat = null
	_event_blur_tween = null


# ═══════════════════════════════════════════════
# 懒加载：Picker 模糊（main.tscn 预建节点）
# ═══════════════════════════════════════════════

func _ensure_picker_blur_overlay() -> bool:
	if _picker_blur_overlay and is_instance_valid(_picker_blur_overlay):
		return true
	if _picker_blur_located and not (_picker_blur_overlay and is_instance_valid(_picker_blur_overlay)):
		Logging.info("%s: PickerBlurOverlay 已失效，重新定位" % LOG_TAG)
		_picker_blur_located = false
		_picker_blur_overlay = null

	if _picker_blur_located:
		return false

	_picker_blur_located = true

	var main := _find_main_node()
	if not main:
		Logging.err("%s: 找不到 Main 节点，Picker 模糊不可用" % LOG_TAG)
		return false

	_picker_blur_overlay = main.find_child("PickerBlurOverlay", true, false) as ColorRect
	if not _picker_blur_overlay:
		Logging.err("%s: 找不到 PickerBlurOverlay 节点" % LOG_TAG)
		return false

	Logging.info("%s: PickerBlurOverlay 定位成功" % LOG_TAG)
	return true


func _find_main_node() -> Node:
	var root := get_tree().root
	var main := root.get_node_or_null("Main") as Node
	if main:
		return main
	for child in root.get_children():
		if child.name.begins_with("main"):
			return child
	return null


# ═══════════════════════════════════════════════
# 公共 API — Picker 模糊
# ═══════════════════════════════════════════════

func show_picker_blur() -> void:
	if not _ensure_picker_blur_overlay():
		return

	if _picker_blur_tween and _picker_blur_tween.is_valid():
		_picker_blur_tween.kill()

	_picker_blur_overlay.show()
	_picker_blur_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_picker_blur_tween.set_parallel(true)
	_picker_blur_tween.tween_property(_picker_blur_overlay.material, "shader_parameter/blur_amount", PICKER_BLUR_AMOUNT, PICKER_BLUR_DURATION)
	_picker_blur_tween.tween_property(_picker_blur_overlay.material, "shader_parameter/darken_amount", PICKER_DARKEN_AMOUNT, PICKER_BLUR_DURATION)
	Logging.info("%s: Picker 模糊已触发（layer=50, blur=%.1f darken=%.1f duration=%.1fs）" % [
		LOG_TAG, PICKER_BLUR_AMOUNT, PICKER_DARKEN_AMOUNT, PICKER_BLUR_DURATION,
	])


func hide_picker_blur() -> void:
	if not _ensure_picker_blur_overlay():
		return

	if _picker_blur_tween and _picker_blur_tween.is_valid():
		_picker_blur_tween.kill()

	_picker_blur_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_picker_blur_tween.set_parallel(true)
	_picker_blur_tween.tween_property(_picker_blur_overlay.material, "shader_parameter/blur_amount", 0.0, PICKER_BLUR_DURATION)
	_picker_blur_tween.tween_property(_picker_blur_overlay.material, "shader_parameter/darken_amount", 0.0, PICKER_BLUR_DURATION)
	_picker_blur_tween.finished.connect(_picker_blur_overlay.hide, CONNECT_ONE_SHOT)
	Logging.info("%s: Picker 模糊已清除" % LOG_TAG)


# ═══════════════════════════════════════════════
# 公共 API — Cinematic 过场后模糊（layer=100）
# ═══════════════════════════════════════════════

## Cinematic 播放结束后，创建独立的顶层 CanvasLayer（layer=100），覆盖一切。
## 与事件模糊（layer=0）互不干扰，各自独立创建/销毁。
##
## 模糊在 `fade_in` 秒内渐入，保持 `duration` 秒后渐出并销毁。
## 期间阻塞调用方（await）。
##
## 参数:
##   duration: 模糊持续的总时长（包括淡入淡出）。默认 3.0 秒。
func trigger_cinematic_post_blur(duration: float = 3.0) -> void:
	Logging.info("%s: trigger_cinematic_post_blur 进入, duration=%.1f" % [LOG_TAG, duration])

	var shader := load("res://shaders/blur_bg.gdshader") as Shader
	if not shader:
		Logging.err("%s: 无法加载 blur_bg.gdshader" % LOG_TAG)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set("shader_parameter/blur_amount", 0.0)
	mat.set("shader_parameter/darken_amount", 0.0)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "CinematicPostBlurLayer"
	canvas_layer.layer = CINEMATIC_LAYER

	var overlay := ColorRect.new()
	overlay.name = "CinematicPostBlurOverlay"
	overlay.material = mat
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	canvas_layer.add_child(overlay)
	get_tree().root.add_child(canvas_layer)

	# 手动设置尺寸（CanvasLayer 中 anchors 可能不生效）
	var set_overlay_size := func():
		var vp := get_viewport()
		if not vp or not is_instance_valid(overlay):
			return
		overlay.size = vp.get_visible_rect().size
		overlay.position = Vector2.ZERO
	set_overlay_size.call()
	get_tree().root.size_changed.connect(set_overlay_size, CONNECT_ONE_SHOT)

	var fade_in: float = CINEMATIC_POST_FADE_IN
	var fade_out: float = CINEMATIC_POST_FADE_OUT
	var hold: float = maxf(duration - fade_in - fade_out, 0.0)

	Logging.info("%s: 触发 Cinematic 后模糊 (blur=%.1f darken=%.1f fade_in=%.1fs hold=%.1fs fade_out=%.1fs, layer=%d)" % [
		LOG_TAG, CINEMATIC_POST_BLUR_AMOUNT, CINEMATIC_POST_DARKEN_AMOUNT, fade_in, hold, fade_out, CINEMATIC_LAYER,
	])

	# 1. 淡入
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(mat, "shader_parameter/blur_amount", CINEMATIC_POST_BLUR_AMOUNT, fade_in)
	tween.tween_property(mat, "shader_parameter/darken_amount", CINEMATIC_POST_DARKEN_AMOUNT, fade_in)
	await tween.finished
	Logging.info("%s: Cinematic 淡入完成" % LOG_TAG)

	# 2. 保持
	if hold > 0.0:
		var hold_timer := Timer.new()
		hold_timer.wait_time = hold
		hold_timer.one_shot = true
		hold_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(hold_timer)
		hold_timer.start()
		await hold_timer.timeout
		hold_timer.queue_free()

	# 3. 淡出
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(mat, "shader_parameter/blur_amount", 0.0, fade_out)
	tween.tween_property(mat, "shader_parameter/darken_amount", 0.0, fade_out)
	await tween.finished

	# 4. 清理
	canvas_layer.queue_free()
	Logging.info("%s: Cinematic 后模糊结束" % LOG_TAG)
