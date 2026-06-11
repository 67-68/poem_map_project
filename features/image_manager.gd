extends Node
## 全局图像管理 Autoload
##
## 用法:
##   var img = ImageManager.present(tex, pos)       # 展示 (Texture2D)
##   var img = ImageManager.present_by_id("id", ENUMS.IMAGE_POS.CENTER)  # 展示 (by ID)
##   var img = ImageManager.recall("id")             # 回溯已有句柄 (无需 Texture2D)
##   await img.slide_to(target_pos, 1.5)            # 滑动
##   img.shatter(1.2)                                # 粉碎
##
##   便捷方法 (fire-and-forget):
##   ImageManager.play_shatter(tex, pos, duration)
##   ImageManager.play_slide(tex, from, to, duration)

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
## [param size] 目标显示尺寸 (默认 100x100)，保持宽高比缩放
func present(tex: Texture2D, global_pos: Vector2, size: Vector2 = Vector2(100, 100)) -> ImageHandle:
	# 确保 CanvasLayer 已正确挂载到场景树（延迟初始化）
	_ensure_effect_layer()
	if _effect_layer == null or not is_instance_valid(_effect_layer):
		Logging.err("%s: present 失败，无法创建有效的 CanvasLayer" % LOG_TAG)
		return null
	
	var handle = ImageHandle.new(tex, global_pos, _effect_layer, size)
	_effect_layer.add_child(handle._sprite)
	_active_handles.append(handle)
	handle._sprite.tree_exited.connect(_on_handle_freed.bind(handle))
	Logging.info("%s: present → tex=%s pos=%s, sprite_name=%s" % [LOG_TAG, tex.resource_path, global_pos, handle._sprite.name])
	return handle


## 便捷方法: 快速粉碎
func play_shatter(tex: Texture2D, pos: Vector2, duration: float = 1.0, params: Dictionary = {}) -> void:
	var handle = present(tex, pos)
	handle.shatter(duration, params)


## 便捷方法: 快速滑动
func play_slide(tex: Texture2D, from: Vector2, to: Vector2, duration: float = 1.0) -> void:
	var handle = present(tex, from)
	handle.slide_to(to, duration)


# ── ID 化 API ──────────────────────────────────────────────

## 注册纹理到 ID 注册表
func register_image(id: String, tex: Texture2D) -> void:
	_texture_registry[id] = tex
	Logging.debug("%s: register_image → id=%s tex=%s" % [LOG_TAG, id, tex.resource_path])


## 按 ID 展示图片。纹理按以下优先级解析:
##   1. _texture_registry 中已注册
##   2. TextureResLoader.get_background(id) 兜底
##   3. TextureResLoader.get_icon_simpler(id) 兜底
func present_by_id(id: String, pos: ENUMS.IMAGE_POS, size: Vector2 = Vector2(100, 100)) -> ImageHandle:
	var tex = _resolve_texture(id)
	if tex == null:
		Logging.err("%s: present_by_id 失败，无法解析纹理: id=%s" % [LOG_TAG, id])
		return null

	var global_pos = _resolve_pos(pos)
	var handle = present(tex, global_pos, size)
	_active_images[id] = handle
	Logging.info("%s: present_by_id → id=%s pos=%s" % [LOG_TAG, id, ENUMS.IMAGE_POS.keys()[pos]])
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


## 解析 IMAGE_POS 枚举 → 全局屏幕坐标 Vector2
func _resolve_pos(pos: ENUMS.IMAGE_POS) -> Vector2:
	var screen := Vector2()
	if get_viewport() != null:
		screen = get_viewport().get_visible_rect().size
	else:
		# fallback: 1920x1080
		screen = Vector2(1920, 1080)

	match pos:
		ENUMS.IMAGE_POS.CENTER:
			return screen * 0.5
		ENUMS.IMAGE_POS.TOP_LEFT:
			return Vector2.ZERO
		ENUMS.IMAGE_POS.TOP_CENTER:
			return Vector2(screen.x * 0.5, 0)
		ENUMS.IMAGE_POS.TOP_RIGHT:
			return Vector2(screen.x, 0)
		ENUMS.IMAGE_POS.CENTER_LEFT:
			return Vector2(0, screen.y * 0.5)
		ENUMS.IMAGE_POS.CENTER_RIGHT:
			return Vector2(screen.x, screen.y * 0.5)
		ENUMS.IMAGE_POS.BOTTOM_LEFT:
			return Vector2(0, screen.y)
		ENUMS.IMAGE_POS.BOTTOM_CENTER:
			return Vector2(screen.x * 0.5, screen.y)
		ENUMS.IMAGE_POS.BOTTOM_RIGHT:
			return screen
		ENUMS.IMAGE_POS.FULL_SCREEN:
			return screen * 0.5
		_:
			return screen * 0.5


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
