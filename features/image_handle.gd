class_name ImageHandle extends RefCounted
## 图片操作句柄 — 代表屏幕上一张图, 可链式操作
##
## 由 ImageManager.present() 创建, 调用方持有此句柄后:
##   - slide_to(): 将图片从当前位置(UV)滑到目标(UV)
##   - shatter():  粉碎图片 (切换 ShaderMaterial) 并销毁
##   - fade_out(): 淡出并销毁
##   - remove():   立即销毁
##
## 所有位置参数使用 UV 坐标 (0.0~1.0, 屏幕归一化空间)。
##
## ⚠️ 所有 Tween 均使用 TWEEN_PAUSE_PROCESS 模式，确保在场景树暂停
##    （如 FocusedChat/事件弹窗期间 TimeService.pause_world）时动画
##    仍能正常播放。如果发现动画在弹窗后卡住不播，优先检查 Tween
##    创建时是否遗漏了 set_pause_mode 调用。

const LOG_TAG := "ImageHandle"
const SHATTER_SHADER := preload("res://shaders/image_shatter.gdshader")

var _sprite: Sprite2D
var _tween: Tween
var _layer: CanvasLayer

## 创建句柄, 由 ImageManager.present() 内部调用
## [param tex] 纹理
## [param uv] 屏幕归一化 UV 坐标 (0.0~1.0)
## [param layer] 父级 CanvasLayer, 用于获取 Viewport
## [param size] 目标显示尺寸 (默认 100x100)，保持宽高比缩放
func _init(tex: Texture2D, uv: Vector2, layer: CanvasLayer, size: Vector2 = Vector2(100, 100)) -> void:
	_layer = layer
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.global_position = _uv_to_pixel(uv)
	_sprite.centered = true
	# 给个默认材质确保 modulate 可用
	_sprite.material = CanvasItemMaterial.new()
	
	# 按目标尺寸缩放，保持宽高比 (cover 模式: min 确保完全可见)
	var tex_size := tex.get_size()
	if tex_size != Vector2.ZERO and size != Vector2.ZERO:
		var scale: float = minf(size.x / tex_size.x, size.y / tex_size.y)
		_sprite.scale = Vector2(scale, scale)
		Logging.debug("%s: 缩放 size=%s tex_size=%s scale=%.4f" % [LOG_TAG, size, tex_size, scale])


## 滑动到目标位置 (UV 坐标)
## 返回 Signal (tween.finished) 以便调用方 await
func slide_to(target_uv: Vector2, duration: float = 1.0) -> Signal:
	_kill_tween()
	var target_pixel := _uv_to_pixel(target_uv)
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_sprite, "global_position", target_pixel, duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	Logging.debug("%s: slide_to → uv=%s pixel=%s duration=%.2f" % [LOG_TAG, target_uv, target_pixel, duration])
	return _tween.finished


## 粉碎解体 (复用 image_shatter.gdshader)
## 播完后自动销毁
func shatter(duration: float = 1.0, params: Dictionary = {}) -> void:
	# 切换为 ShaderMaterial
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SHATTER_SHADER
	_sprite.material = shader_mat

	# 设置 shader 参数
	shader_mat.set_shader_parameter("progress", 0.0)
	for key in params:
		if shader_mat.get_shader_parameter(key) != null:
			shader_mat.set_shader_parameter(key, params[key])
		else:
			Logging.warn("%s: 未知 shader 参数 '%s', 跳过" % [LOG_TAG, key])

	Logging.debug("%s: shatter → duration=%.2f params=%s" % [LOG_TAG, duration, params])

	# Tween 驱动
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_update_shader_progress.bind(shader_mat), 0.0, 1.0, duration)
	_tween.finished.connect(_destroy)


## 淡出消散
func fade_out(duration: float = 1.0) -> void:
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_sprite, "modulate:a", 0.0, duration)
	_tween.finished.connect(_destroy)
	Logging.debug("%s: fade_out → duration=%.2f" % [LOG_TAG, duration])


## 立即销毁
func remove() -> void:
	Logging.debug("%s: remove" % LOG_TAG)
	_destroy()


# ── 属性修改 (返回 self 支持链式) ─────────────────────

func set_opacity(alpha: float) -> ImageHandle:
	var c := _sprite.modulate
	c.a = alpha
	_sprite.modulate = c
	return self


func set_scale(s: Vector2) -> ImageHandle:
	_sprite.scale = s
	return self


func set_modulate(color: Color) -> ImageHandle:
	_sprite.modulate = color
	return self


# ── AnimationObject 工厂 ──────────────────────────────

## 创建滑动动画对象（可被 NarrativeOverlay 追踪）
## [param target_uv] 目标 UV 坐标 (0.0~1.0)
func create_slide(target_uv: Vector2, duration: float = 1.0) -> SlideAnimation:
	var target_pixel := _uv_to_pixel(target_uv)
	return SlideAnimation.new(_sprite, target_pixel, duration)


## 创建粉碎动画对象
func create_shatter(duration: float = 1.0, params: Dictionary = {}) -> ShatterAnimation:
	return ShatterAnimation.new(_sprite, duration, params)


## 创建淡出动画对象
func create_fade_out(duration: float = 1.0) -> FadeOutAnimation:
	return FadeOutAnimation.new(_sprite, duration)


# ── 内部 ──────────────────────────────────────────────

## UV → 屏幕像素坐标转换
func _uv_to_pixel(uv: Vector2) -> Vector2:
	var viewport: Viewport
	if _layer != null and _layer.get_viewport() != null:
		viewport = _layer.get_viewport()
	else:
		return Vector2(960, 540)  # fallback

	var screen := viewport.get_visible_rect().size
	return Vector2(screen.x * uv.x, screen.y * uv.y)


func _update_shader_progress(val: float, mat: ShaderMaterial) -> void:
	if mat != null:
		mat.set_shader_parameter("progress", val)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _destroy() -> void:
	_kill_tween()
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
