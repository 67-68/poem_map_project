extends Node
## 全局图像管理 Autoload
##
## 用法:
##   var img = ImageManager.present(tex, uv)        # 展示 (Texture2D, UV 坐标)
##   var img = ImageManager.present_by_id("id", uv) # 展示 (by ID, UV 坐标)
##   var img = ImageManager.recall("id")             # 回溯已有句柄 (无需 Texture2D)
##   await img.slide_to(target_uv, 1.5)             # 滑动 (UV 坐标)
##   img.shatter(1.2)                                # 粉碎
##
##   便捷方法 (fire-and-forget):
##   ImageManager.play_shatter(tex, uv, duration)
##   ImageManager.play_slide(tex, from_uv, to_uv, duration)
##
## 所有位置参数为 UV 坐标 (0.0~1.0, 屏幕归一化空间)。

const LOG_TAG := "ImageManager"

var _effect_layer: CanvasLayer
var _active_handles: Array[ImageHandle] = []

## ID → Texture2D 注册表
var _texture_registry: Dictionary = {}
## ID → ImageHandle 活跃图片回溯表
var _active_images: Dictionary = {}


func _ready() -> void:
	# 注意: CanvasLayer 不在 _ready() 中创建
	# Godot 4 autoload 的 _ready() 期间场景树未完全就绪，
	# get_tree().root.add_child() 无法正确挂载节点（parent 会变成 <Object#null>)
	# 改为在 present() 首次调用时延迟初始化 (_ensure_effect_layer)
	
	# 连接 EventBus 信号 (如果存在 request_play_shatter)
	if EventBus.has_signal("request_play_shatter"):
		EventBus.request_play_shatter.connect(_on_request_play_shatter)
		Logging.debug("%s: 已连接 EventBus.request_play_shatter" % LOG_TAG)
	else:
		Logging.warn("%s: EventBus 缺少 request_play_shatter 信号" % LOG_TAG)


## 展示一张图片并返回操作句柄
## [param uv] 屏幕归一化 UV 坐标 (0.0~1.0)
## [param size] 目标显示尺寸 (默认 100x100)，保持宽高比缩放
func present(tex: Texture2D, uv: Vector2, size: Vector2 = Vector2(100, 100)) -> ImageHandle:
	# 确保 CanvasLayer 已正确挂载到场景树（延迟初始化）
	_ensure_effect_layer()
	if _effect_layer == null or not is_instance_valid(_effect_layer):
		Logging.err("%s: present 失败，无法创建有效的 CanvasLayer" % LOG_TAG)
		return null
	
	var handle = ImageHandle.new(tex, uv, _effect_layer, size)
	_effect_layer.add_child(handle._sprite)
	_active_handles.append(handle)
	handle._sprite.tree_exited.connect(_on_handle_freed.bind(handle))
	Logging.info("%s: present → tex=%s uv=%s, sprite_name=%s" % [LOG_TAG, tex.resource_path, uv, handle._sprite.name])
	return handle


## 便捷方法: 快速粉碎
## [param uv] 屏幕归一化 UV 坐标 (0.0~1.0)
func play_shatter(tex: Texture2D, uv: Vector2, duration: float = 1.0, params: Dictionary = {}) -> void:
	var handle = present(tex, uv)
	handle.shatter(duration, params)


## 便捷方法: 快速滑动
## [param from_uv] 起始 UV 坐标 (0.0~1.0)
## [param to_uv] 目标 UV 坐标 (0.0~1.0)
func play_slide(tex: Texture2D, from_uv: Vector2, to_uv: Vector2, duration: float = 1.0) -> void:
	var handle = present(tex, from_uv)
	handle.slide_to(to_uv, duration)


# ── ID 化 API ──────────────────────────────────────────────

## 注册纹理到 ID 注册表
func register_image(id: String, tex: Texture2D) -> void:
	_texture_registry[id] = tex
	Logging.debug("%s: register_image → id=%s tex=%s" % [LOG_TAG, id, tex.resource_path])


## 按 ID 展示图片 (UV 坐标)。纹理按以下优先级解析:
##   1. _texture_registry 中已注册
##   2. TextureResLoader.get_background(id) 兜底
##   3. TextureResLoader.get_icon_simpler(id) 兜底
##
## [param uv] 屏幕归一化 UV 坐标 (0.0~1.0)，例如 Vector2(0.5, 0.3) 表示屏幕 50% 横、30% 纵位置。
## [param size] 目标显示尺寸 (默认 100x100)，保持宽高比缩放
func present_by_id(id: String, uv: Vector2, size: Vector2 = Vector2(100, 100)) -> ImageHandle:
	var tex = _resolve_texture(id)
	if tex == null:
		Logging.err("%s: present_by_id 失败，无法解析纹理: id=%s" % [LOG_TAG, id])
		return null

	var handle = present(tex, uv, size)
	_active_images[id] = handle
	Logging.info("%s: present_by_id → id=%s uv=%s" % [LOG_TAG, id, uv])
	return handle


## 按 IMAGE_POS 枚举展示图片 (内部转 UV)。
## [param pos] IMAGE_POS 枚举值 (如 ENUMS.IMAGE_POS.CENTER = Vector2(0.5, 0.5))
## [param size] 目标显示尺寸 (默认 100x100)，保持宽高比缩放
func present_by_enum(id: String, pos: ENUMS.IMAGE_POS, size: Vector2 = Vector2(100, 100)) -> ImageHandle:
	var tex = _resolve_texture(id)
	if tex == null:
		Logging.err("%s: present_by_enum 失败，无法解析纹理: id=%s" % [LOG_TAG, id])
		return null

	var uv := resolve_uv(pos)
	var handle = present(tex, uv, size)
	_active_images[id] = handle
	Logging.info("%s: present_by_enum → id=%s pos=%s uv=%s" % [LOG_TAG, id, ENUMS.IMAGE_POS.keys()[pos], uv])
	return handle


## 回溯已有图片句柄 (无需传递 Texture2D)
## 如果该 ID 对应的图片已被销毁，返回 null
func recall(id: String) -> ImageHandle:
	var handle = _active_images.get(id)
	if handle == null:
		Logging.warn("%s: recall 失败，ID '%s' 没有活跃的图片" % [LOG_TAG, id])
		return null
	Logging.debug("%s: recall → id=%s" % [LOG_TAG, id])
	return handle


## 检查 ID 对应的图片是否仍在屏幕活跃
func has_image(id: String) -> bool:
	return _active_images.has(id)


## 从注册表中移除纹理 (不影响正在展示的图片)
func unregister_image(id: String) -> void:
	_texture_registry.erase(id)
	Logging.debug("%s: unregister_image → id=%s" % [LOG_TAG, id])


# ── 内部 ──────────────────────────────────────────────────

## 确保 CanvasLayer 已正确创建并挂载到场景树。
## 使用延迟初始化模式以规避 autoload _ready() 期间场景树未就绪的问题。
func _ensure_effect_layer() -> void:
	if _effect_layer != null and is_instance_valid(_effect_layer) and _effect_layer.is_inside_tree():
		return
	
	# 首次创建或重新创建（如果之前创建失败/被销毁）
	_effect_layer = CanvasLayer.new()
	_effect_layer.layer = 128
	_effect_layer.name = "ImageEffectLayer"
	get_tree().root.add_child(_effect_layer)
	Logging.info("%s: CanvasLayer 已创建并挂载到 root (parent=%s)" % [LOG_TAG, _effect_layer.get_parent()])


func _on_handle_freed(handle: ImageHandle) -> void:
	_active_handles.erase(handle)
	# 同时清理 _active_images 中的回溯引用
	for id in _active_images.keys():
		if _active_images[id] == handle:
			_active_images.erase(id)
			Logging.debug("%s: _active_images 已清理 id=%s" % [LOG_TAG, id])
			break
	Logging.debug("%s: handle 已释放, 剩余活跃数=%d" % [LOG_TAG, _active_handles.size()])


func _on_request_play_shatter(tex: Texture2D, pos: Vector2, duration: float) -> void:
	play_shatter(tex, pos, duration)


## 解析 IMAGE_POS 枚举 → UV Vector2 (0.0~1.0)
## 例如: CENTER → Vector2(0.5, 0.5), TOP_LEFT → Vector2(0, 0)
func resolve_uv(pos: ENUMS.IMAGE_POS) -> Vector2:
	match pos:
		ENUMS.IMAGE_POS.CENTER:
			return Vector2(0.5, 0.5)
		ENUMS.IMAGE_POS.TOP_LEFT:
			return Vector2(0, 0)
		ENUMS.IMAGE_POS.TOP_CENTER:
			return Vector2(0.5, 0)
		ENUMS.IMAGE_POS.TOP_RIGHT:
			return Vector2(1, 0)
		ENUMS.IMAGE_POS.CENTER_LEFT:
			return Vector2(0, 0.5)
		ENUMS.IMAGE_POS.CENTER_RIGHT:
			return Vector2(1, 0.5)
		ENUMS.IMAGE_POS.BOTTOM_LEFT:
			return Vector2(0, 1)
		ENUMS.IMAGE_POS.BOTTOM_CENTER:
			return Vector2(0.5, 1)
		ENUMS.IMAGE_POS.BOTTOM_RIGHT:
			return Vector2(1, 1)
		ENUMS.IMAGE_POS.FULL_SCREEN:
			return Vector2(0.5, 0.5)
		_:
			return Vector2(0.5, 0.5)


## 解析 ID → Texture2D
## 优先级: 注册表 > TextureResLoader.get_background > TextureResLoader.get_icon_simpler
func _resolve_texture(id: String) -> Texture2D:
	if id.is_empty():
		Logging.warn("%s: _resolve_texture 收到空 id" % LOG_TAG)
		return null

	# 1. 已注册纹理
	if _texture_registry.has(id):
		return _texture_registry[id]

	# 2. 尝试作为 background 加载
	var tex = TextureResLoader.get_background(id)
	if tex:
		_texture_registry[id] = tex
		return tex

	# 3. 尝试作为 icon 加载
	tex = TextureResLoader.get_icon_simpler(id)
	if tex:
		_texture_registry[id] = tex
		return tex

	Logging.err("%s: _resolve_texture 无法解析纹理: id=%s" % [LOG_TAG, id])
	return null


func _exit_tree() -> void:
	if EventBus.has_signal("request_play_shatter") and EventBus.request_play_shatter.is_connected(_on_request_play_shatter):
		EventBus.request_play_shatter.disconnect(_on_request_play_shatter)
