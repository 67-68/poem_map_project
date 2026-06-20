## 高斯模糊管理器 — 可复用的模糊效果控制器
##
## 提供三种模糊模式，共享同一个 CanvasLayer：
##   1. 事件模糊:   事件触发时模糊地图 + 压暗，持续到纸带清空
##   2. Picker 模糊: Picker 激活时在 Layer 50 插入全屏毛玻璃
##                   TapeLayer (layer=100) 纸带悬浮其上，保持清晰
##   3. Cinematic:   复用事件模糊的 CanvasLayer，暂时拉高模糊值，await 后恢复
##
## 关键设计：
##   - 三种模糊必须使用独立于 MapLayer 的 CanvasLayer，
##     因为 Godot 4 的 hint_screen_texture 只能捕获当前 CanvasLayer 之前渲染的视口内容。
##
## 用法：
##   BlurManager.trigger_event_blur()    — 事件触发，模糊地图
##   BlurManager.return_to_hub()         — 纸带清空，清除地图模糊
##   BlurManager.show_picker_blur()      — Picker 展示，Layer 50 毛玻璃渐入
##   BlurManager.hide_picker_blur()      — Picker 完成，Layer 50 毛玻璃渐出

extends Node

const LOG_TAG := "BlurManager"

# ── 共享模糊层：事件模糊 + Cinematic 后模糊共用 ──────
var _shared_blur_canvas_layer: CanvasLayer = null
var _shared_blur_overlay: ColorRect = null
var _shared_blur_mat: ShaderMaterial = null
var _shared_blur_tween: Tween = null

# ── Picker 模糊（main.tscn 预建的 PickerBlurLayer (layer=50) → PickerBlurOverlay）
var _picker_blur_overlay: ColorRect = null
var _picker_blur_tween: Tween = null
var _picker_blur_located: bool = false

# ── 缓动参数 ─────────────────────────────────────────
const MAP_BLUR_IN_AMOUNT: float = 6.0
const MAP_BLUR_OUT_AMOUNT: float = 0.0
const MAP_DARKEN_IN_AMOUNT: float = 0.75
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

# ── 共享模糊层 CanvasLayer 层级 ──────────────────────
# MapLayer=0, SharedBlurLayer=10, PickerBlurLayer=50, TapeLayer=100
const SHARED_BLUR_LAYER: int = 10


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
# 共享模糊层（事件模糊 + Cinematic 后模糊）
# ═══════════════════════════════════════════════

func _ensure_shared_blur_layer() -> bool:
	if _shared_blur_canvas_layer and is_instance_valid(_shared_blur_canvas_layer):
		return true

	Logging.info("%s: 创建共享模糊 CanvasLayer (layer=%d)" % [LOG_TAG, SHARED_BLUR_LAYER])

	var shader := load("res://shaders/blur_bg.gdshader") as Shader
	if not shader:
		Logging.err("%s: 无法加载 blur_bg.gdshader" % LOG_TAG)
		return false

	_shared_blur_mat = ShaderMaterial.new()
	_shared_blur_mat.shader = shader
	_shared_blur_mat.set("shader_parameter/blur_amount", 0.0)
	_shared_blur_mat.set("shader_parameter/darken_amount", 0.0)

	_shared_blur_canvas_layer = CanvasLayer.new()
	_shared_blur_canvas_layer.name = "SharedBlurLayer"
	_shared_blur_canvas_layer.layer = SHARED_BLUR_LAYER

	_shared_blur_overlay = ColorRect.new()
	_shared_blur_overlay.name = "SharedBlurOverlay"
	_shared_blur_overlay.material = _shared_blur_mat
	_shared_blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shared_blur_canvas_layer.add_child(_shared_blur_overlay)
	get_tree().root.add_child(_shared_blur_canvas_layer)

	_set_shared_blur_fullscreen()

	if not get_tree().root.size_changed.is_connected(_set_shared_blur_fullscreen):
		get_tree().root.size_changed.connect(_set_shared_blur_fullscreen)

	Logging.info("%s: SharedBlurLayer 创建完成, layer=%d, size=%s" % [
		LOG_TAG,
		_shared_blur_canvas_layer.layer,
		_shared_blur_overlay.size,
	])
	return true


func _set_shared_blur_fullscreen() -> void:
	if not _shared_blur_overlay or not is_instance_valid(_shared_blur_overlay):
		return
	var vp_size := get_viewport().get_visible_rect().size
	_shared_blur_overlay.position = Vector2.ZERO
	_shared_blur_overlay.size = vp_size


func _kill_shared_blur_tween() -> void:
	if _shared_blur_tween and _shared_blur_tween.is_valid():
		_shared_blur_tween.kill()
	_shared_blur_tween = null


# ═══════════════════════════════════════════════
# 公共 API — 事件模糊
# ═══════════════════════════════════════════════

## 事件触发：模糊地图 + 压暗（idempotent）
func trigger_event_blur() -> void:
	if not _ensure_shared_blur_layer():
		return

	_kill_shared_blur_tween()

	Logging.info("%s: 触发事件模糊 (blur=%.1f darken=%.1f)" % [LOG_TAG, MAP_BLUR_IN_AMOUNT, MAP_DARKEN_IN_AMOUNT])

	_shared_blur_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shared_blur_tween.set_parallel(true)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/blur_amount", MAP_BLUR_IN_AMOUNT, MAP_BLUR_IN_DURATION)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/darken_amount", MAP_DARKEN_IN_AMOUNT, MAP_BLUR_IN_DURATION)


## 纸带清空：清除地图模糊，销毁共享模糊层
func return_to_hub() -> void:
	if not _shared_blur_canvas_layer or not is_instance_valid(_shared_blur_canvas_layer):
		return

	_kill_shared_blur_tween()

	Logging.info("%s: 清除事件模糊" % LOG_TAG)

	_shared_blur_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shared_blur_tween.set_parallel(true)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/blur_amount", MAP_BLUR_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/darken_amount", MAP_DARKEN_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)
	_shared_blur_tween.finished.connect(_destroy_shared_blur_layer, CONNECT_ONE_SHOT)


func _destroy_shared_blur_layer() -> void:
	if _shared_blur_canvas_layer and is_instance_valid(_shared_blur_canvas_layer):
		if get_tree() and get_tree().root.size_changed.is_connected(_set_shared_blur_fullscreen):
			get_tree().root.size_changed.disconnect(_set_shared_blur_fullscreen)
		_shared_blur_canvas_layer.queue_free()
		Logging.info("%s: SharedBlurLayer 已销毁" % LOG_TAG)
	_shared_blur_canvas_layer = null
	_shared_blur_overlay = null
	_shared_blur_mat = null
	_shared_blur_tween = null


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
# 公共 API — Cinematic 过场后模糊
# ═══════════════════════════════════════════════

## Cinematic 播放结束后，复用共享模糊层，暂时拉高模糊值，形成「余韵」过渡。
## 模糊在 `fade_in` 秒内渐入，保持 `duration` 秒后渐出。
## 期间阻塞调用方（await）。
##
## 参数:
##   duration: 模糊持续的总时长（包括淡入淡出）。默认 3.0 秒。
func trigger_cinematic_post_blur(duration: float = 3.0) -> void:
	Logging.info("%s: trigger_cinematic_post_blur 进入, duration=%.1f" % [LOG_TAG, duration])

	if not _ensure_shared_blur_layer():
		return

	# 保存当前模糊参数，结束后恢复
	var saved_blur: float = _shared_blur_mat.get("shader_parameter/blur_amount")
	var saved_darken: float = _shared_blur_mat.get("shader_parameter/darken_amount")
	Logging.info("%s: 保存当前参数 blur=%.2f darken=%.2f" % [LOG_TAG, saved_blur, saved_darken])

	_kill_shared_blur_tween()

	var fade_in: float = CINEMATIC_POST_FADE_IN
	var fade_out: float = CINEMATIC_POST_FADE_OUT
	var hold: float = maxf(duration - fade_in - fade_out, 0.0)

	Logging.info("%s: 触发 Cinematic 后模糊 (blur=%.1f darken=%.1f fade_in=%.1fs hold=%.1fs fade_out=%.1fs)" % [
		LOG_TAG, CINEMATIC_POST_BLUR_AMOUNT, CINEMATIC_POST_DARKEN_AMOUNT, fade_in, hold, fade_out,
	])

	# 1. 淡入
	_shared_blur_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shared_blur_tween.set_parallel(true)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/blur_amount", CINEMATIC_POST_BLUR_AMOUNT, fade_in)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/darken_amount", CINEMATIC_POST_DARKEN_AMOUNT, fade_in)
	await _shared_blur_tween.finished
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

	# 3. 淡出到保存的值
	Logging.info("%s: Cinematic 淡出，恢复到 blur=%.2f darken=%.2f" % [LOG_TAG, saved_blur, saved_darken])
	_shared_blur_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shared_blur_tween.set_parallel(true)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/blur_amount", saved_blur, fade_out)
	_shared_blur_tween.tween_property(_shared_blur_mat, "shader_parameter/darken_amount", saved_darken, fade_out)
	await _shared_blur_tween.finished

	Logging.info("%s: Cinematic 后模糊结束" % LOG_TAG)
