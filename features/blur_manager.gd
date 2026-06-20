## 高斯模糊管理器 — 可复用的模糊效果控制器
##
## 提供两种模糊模式：
##   1. 地图模糊: 事件触发时模糊地图 + 压暗背景
##   2. Picker 模糊: Picker 激活时在 UI 层插入模糊遮罩，模糊其他控件
##
## 用法：
##   BlurManager.trigger_event_blur()    — 事件触发，模糊地图
##   BlurManager.return_to_hub()         — 纸带清空，清除地图模糊
##   BlurManager.trigger_picker_blur()   — Picker 展示，模糊其他 UI
##   BlurManager.end_picker_blur()       — Picker 完成，清除 UI 模糊

extends Node

const LOG_TAG := "BlurManager"

# ── 地图模糊（main.tscn 中已有的 BlurOverlay）─────────
var _map_overlay: ColorRect = null
var _map_tween: Tween = null
var _map_overlay_located: bool = false

# ── Picker UI 模糊（运行时动态创建）────────────────────
var _picker_overlay: ColorRect = null
var _picker_tween: Tween = null
var _picker_overlay_created: bool = false

# Picker 模糊层 z_index — 高于常规 UI 控件，低于 NarrativeOverlay (z_index=8)
const PICKER_BLUR_Z_INDEX := 5

# ── 缓动参数 ─────────────────────────────────────────
const MAP_BLUR_IN_AMOUNT: float = 3.0
const MAP_BLUR_OUT_AMOUNT: float = 0.0
const MAP_DARKEN_IN_AMOUNT: float = 0.6
const MAP_DARKEN_OUT_AMOUNT: float = 0.0
const MAP_BLUR_IN_DURATION: float = 1.0
const MAP_BLUR_OUT_DURATION: float = 0.8

const PICKER_BLUR_AMOUNT: float = 2.0
const PICKER_DARKEN_AMOUNT: float = 0.3
const PICKER_BLUR_DURATION: float = 0.5

# ── Cinematic 过场后模糊 ──────────────────────────────
const CINEMATIC_POST_BLUR_AMOUNT: float = 5.0
const CINEMATIC_POST_DARKEN_AMOUNT: float = 0.85
const CINEMATIC_POST_FADE_IN: float = 0.8
const CINEMATIC_POST_FADE_OUT: float = 0.8


# ═══════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# autoload _ready 在主场景加载之前执行，延迟初始化
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_ensure_map_overlay()
	_ensure_picker_overlay()
	Logging.info("%s: 延迟初始化完成，map=%s picker=%s" % [
		LOG_TAG,
		"OK" if _map_overlay else "MISSING",
		"OK" if _picker_overlay else "MISSING",
	])


# ═══════════════════════════════════════════════
# 懒加载：地图模糊
# ═══════════════════════════════════════════════

func _ensure_map_overlay() -> bool:
	if _map_overlay and is_instance_valid(_map_overlay):
		return true
	# 节点已失效 → 重置标记，允许重新查找（防止场景切换后永久罢工）
	if _map_overlay_located and not (_map_overlay and is_instance_valid(_map_overlay)):
		Logging.info("%s: 地图遮罩已失效，重新定位" % LOG_TAG)
		_map_overlay_located = false
		_map_overlay = null

	if _map_overlay_located:
		return false  # 已经找过但没找到，不再重复找

	_map_overlay_located = true

	var main := _find_main_node()
	if not main:
		Logging.err("%s: 找不到 Main 节点，地图模糊不可用" % LOG_TAG)
		return false

	var map_layer := main.find_child("MapLayer", true, false)
	if not map_layer:
		Logging.err("%s: 找不到 MapLayer，地图模糊不可用" % LOG_TAG)
		return false

	_map_overlay = map_layer.find_child("BlurOverlay", true, false) as ColorRect
	if not _map_overlay:
		Logging.err("%s: 找不到 BlurOverlay 节点，地图模糊不可用" % LOG_TAG)
		return false

	# 确保初始状态：无模糊
	_map_overlay.material.set("shader_parameter/blur_amount", 0.0)
	_map_overlay.material.set("shader_parameter/darken_amount", 0.0)
	Logging.info("%s: 地图 BlurOverlay 定位成功" % LOG_TAG)
	return true


# ═══════════════════════════════════════════════
# 懒加载：Picker 模糊
# ═══════════════════════════════════════════════

func _ensure_picker_overlay() -> bool:
	if _picker_overlay and is_instance_valid(_picker_overlay):
		return true
	# 节点已失效 → 重置标记，允许重新查找（防止场景切换后永久罢工）
	if _picker_overlay_created and not (_picker_overlay and is_instance_valid(_picker_overlay)):
		Logging.info("%s: Picker 遮罩已失效，重新创建" % LOG_TAG)
		_picker_overlay_created = false
		_picker_overlay = null

	if _picker_overlay_created:
		return false

	_picker_overlay_created = true

	var main := _find_main_node()
	if not main:
		Logging.err("%s: 找不到 Main 节点，Picker 模糊不可用" % LOG_TAG)
		return false

	var ui_layer := main.find_child("UI", true, false) as CanvasLayer
	if not ui_layer:
		Logging.err("%s: 找不到 UI CanvasLayer，Picker 模糊不可用" % LOG_TAG)
		return false

	var shader := load("res://shaders/blur_bg.gdshader") as Shader
	if not shader:
		Logging.err("%s: 无法加载 blur_bg.gdshader，Picker 模糊不可用" % LOG_TAG)
		return false

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set("shader_parameter/blur_amount", 0.0)
	mat.set("shader_parameter/darken_amount", 0.0)

	_picker_overlay = ColorRect.new()
	_picker_overlay.name = "PickerBlurOverlay"
	_picker_overlay.z_index = PICKER_BLUR_Z_INDEX
	_picker_overlay.material = mat
	_picker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker_overlay.hide()

	# 铺满全屏
	_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	ui_layer.add_child(_picker_overlay)
	Logging.info("%s: PickerBlurOverlay 创建成功（z_index=%d）" % [LOG_TAG, PICKER_BLUR_Z_INDEX])
	return true


# ═══════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════

func _find_main_node() -> Node:
	var root := get_tree().root
	return root.find_child("Main", true, false)


# ═══════════════════════════════════════════════
# 公共 API — 地图模糊
# ═══════════════════════════════════════════════

## 事件触发：模糊地图 + 压暗（idempotent，重复调用无副作用）
func trigger_event_blur() -> void:
	if not _ensure_map_overlay():
		return

	if _map_tween and _map_tween.is_valid():
		_map_tween.kill()

	Logging.info("%s: 触发地图模糊 (blur=%.1f darken=%.1f)" % [LOG_TAG, MAP_BLUR_IN_AMOUNT, MAP_DARKEN_IN_AMOUNT])

	_map_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_map_tween.set_parallel(true)
	_map_tween.tween_property(_map_overlay.material, "shader_parameter/blur_amount", MAP_BLUR_IN_AMOUNT, MAP_BLUR_IN_DURATION)
	_map_tween.tween_property(_map_overlay.material, "shader_parameter/darken_amount", MAP_DARKEN_IN_AMOUNT, MAP_BLUR_IN_DURATION)


## 纸带清空：清除地图模糊 — 拨云见日（idempotent）
func return_to_hub() -> void:
	if not _ensure_map_overlay():
		return

	if _map_tween and _map_tween.is_valid():
		_map_tween.kill()

	Logging.info("%s: 清除地图模糊 — 拨云见日" % LOG_TAG)

	_map_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_map_tween.set_parallel(true)
	_map_tween.tween_property(_map_overlay.material, "shader_parameter/blur_amount", MAP_BLUR_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)
	_map_tween.tween_property(_map_overlay.material, "shader_parameter/darken_amount", MAP_DARKEN_OUT_AMOUNT, MAP_BLUR_OUT_DURATION)


# ═══════════════════════════════════════════════
# 公共 API — Picker 模糊
# ═══════════════════════════════════════════════

## Picker 展示时：在 UI 层上覆盖模糊遮罩，模糊其他控件
## NarrativeOverlay (z_index=8) 会自然地浮在模糊层之上，保持清晰
func trigger_picker_blur() -> void:
	if not _ensure_picker_overlay():
		return

	_picker_overlay.show()

	if _picker_tween and _picker_tween.is_valid():
		_picker_tween.kill()

	Logging.info("%s: 触发 Picker UI 模糊 (blur=%.1f)" % [LOG_TAG, PICKER_BLUR_AMOUNT])

	_picker_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_picker_tween.set_parallel(true)
	_picker_tween.tween_property(_picker_overlay.material, "shader_parameter/blur_amount", PICKER_BLUR_AMOUNT, PICKER_BLUR_DURATION)
	_picker_tween.tween_property(_picker_overlay.material, "shader_parameter/darken_amount", PICKER_DARKEN_AMOUNT, PICKER_BLUR_DURATION)


## Picker 完成：清除 UI 模糊
func end_picker_blur() -> void:
	if not _ensure_picker_overlay():
		return

	if _picker_tween and _picker_tween.is_valid():
		_picker_tween.kill()

	Logging.info("%s: 清除 Picker UI 模糊" % LOG_TAG)

	_picker_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_picker_tween.set_parallel(true)
	_picker_tween.tween_property(_picker_overlay.material, "shader_parameter/blur_amount", 0.0, PICKER_BLUR_DURATION)
	_picker_tween.tween_property(_picker_overlay.material, "shader_parameter/darken_amount", 0.0, PICKER_BLUR_DURATION)

	# 缓动结束后隐藏节点
	_picker_tween.finished.connect(_picker_overlay.hide, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════
# 公共 API — Cinematic 过场后模糊
# ═══════════════════════════════════════════════

## Cinematic 播放结束后，触发全屏高斯模糊 + 压暗效果。
## 创建独立的顶层 CanvasLayer（layer=100），确保 screen_texture
## 能捕获完整前后帧画面，不受现有 UI 层级限制。
##
## 模糊在 `fade_in` 秒内渐入，保持 `duration` 秒后渐出。
## 期间阻塞调用方（await），常用于纸带中插入「余韵」过渡。
##
## 参数:
##   duration: 模糊持续的总时长（包括淡入淡出）。默认 5.0 秒。
func trigger_cinematic_post_blur(duration: float = 5.0) -> void:
	Logging.info("%s: trigger_cinematic_post_blur 进入, duration=%.1f" % [LOG_TAG, duration])

	var shader := load("res://shaders/blur_bg.gdshader") as Shader
	if not shader:
		Logging.err("%s: 无法加载 blur_bg.gdshader，Cinematic 后模糊跳过" % LOG_TAG)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set("shader_parameter/blur_amount", 0.0)
	mat.set("shader_parameter/darken_amount", 0.0)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "CinematicPostBlurLayer"
	canvas_layer.layer = 100  # 在所有其他 CanvasLayer 之上渲染

	var overlay := ColorRect.new()
	overlay.name = "CinematicPostBlurOverlay"
	overlay.material = mat
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	canvas_layer.add_child(overlay)
	get_tree().root.add_child(canvas_layer)

	Logging.info("%s: [诊断] CinematicPostBlurLayer 创建, layer=%d, 铺满全屏" % [LOG_TAG, canvas_layer.layer])

	var fade_in: float = CINEMATIC_POST_FADE_IN
	var fade_out: float = CINEMATIC_POST_FADE_OUT
	var hold: float = maxf(duration - fade_in - fade_out, 0.0)

	Logging.info("%s: 触发 Cinematic 后模糊 (blur=%.1f darken=%.1f fade_in=%.1fs hold=%.1fs fade_out=%.1fs)" % [
		LOG_TAG, CINEMATIC_POST_BLUR_AMOUNT, CINEMATIC_POST_DARKEN_AMOUNT, fade_in, hold, fade_out,
	])

	# ── 诊断 3 修复：ColorRect 在 CanvasLayer 中 set_anchors_preset 无法自动铺满。
	#    手动设为视口尺寸，并监听窗口大小变化。
	var set_overlay_size := func():
		var vp_size := get_viewport().get_visible_rect().size
		overlay.size = vp_size
		overlay.position = Vector2.ZERO
		Logging.info("%s: [诊断] 手动设置 overlay 尺寸为 %s" % [LOG_TAG, vp_size])
	set_overlay_size.call()
	get_tree().root.size_changed.connect(set_overlay_size, CONNECT_ONE_SHOT)

	# 1. 淡入模糊
	# ── 诊断 2 修复：Tween 必须设置 TWEEN_PAUSE_PROCESS，否则游戏暂停时缓动卡在 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(mat, "shader_parameter/blur_amount", CINEMATIC_POST_BLUR_AMOUNT, fade_in)
	tween.tween_property(mat, "shader_parameter/darken_amount", CINEMATIC_POST_DARKEN_AMOUNT, fade_in)
	Logging.info("%s: [诊断] tween 淡入已创建 (TWEEN_PAUSE_PROCESS), 等待 %.1fs ..." % [LOG_TAG, fade_in])
	await tween.finished
	Logging.info("%s: [诊断] 淡入完成, blur_amount=%.2f darken_amount=%.2f" % [
		LOG_TAG,
		mat.get("shader_parameter/blur_amount"),
		mat.get("shader_parameter/darken_amount"),
	])

	# 2. 保持模糊（hold）
	if hold > 0.0:
		Logging.info("%s: [诊断] 进入 hold 阶段, %.1fs" % [LOG_TAG, hold])
		var hold_timer := Timer.new()
		hold_timer.wait_time = hold
		hold_timer.one_shot = true
		hold_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(hold_timer)
		hold_timer.start()
		await hold_timer.timeout
		hold_timer.queue_free()
		Logging.info("%s: [诊断] hold 结束" % LOG_TAG)

	# 3. 淡出模糊
	Logging.info("%s: [诊断] 进入淡出阶段, %.1fs" % [LOG_TAG, fade_out])
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(mat, "shader_parameter/blur_amount", 0.0, fade_out)
	tween.tween_property(mat, "shader_parameter/darken_amount", 0.0, fade_out)
	await tween.finished
	Logging.info("%s: [诊断] 淡出完成, blur_amount=%.2f darken_amount=%.2f" % [
		LOG_TAG,
		mat.get("shader_parameter/blur_amount"),
		mat.get("shader_parameter/darken_amount"),
	])

	# 4. 清理
	canvas_layer.queue_free()
	Logging.info("%s: Cinematic 后模糊结束，CanvasLayer 已释放" % LOG_TAG)
