extends Node

# ============================================================
# ImageEffectManager — 图像特效全局管理器
#
# 职责:
#   - 创建并管理顶层 ImageEffectLayer (CanvasLayer)
#   - 提供 play_* 工厂方法生成特效实例
#   - 日志记录所有特效 spawn
#
# 用法:
#   ImageEffectManager.play_shatter(texture, global_position)
#   EventBus.request_play_shatter.emit(texture, global_position)
# ============================================================

const LOG_TAG := "ImageEffectManager"

# ── 预加载特效场景 ──────────────────────────────────────────
const SHATTER_SCENE := preload("res://effects/shatter_effect.tscn")

# ── 特效层常量 ─────────────────────────────────────────────
const EFFECT_LAYER_NAME := "ImageEffectLayer"
const EFFECT_LAYER_INDEX := 128

# ── 状态 ──────────────────────────────────────────────────
var _effect_layer: CanvasLayer = null
var _is_ready := false

# ============================================================
# 生命周期
# ============================================================

func _enter_tree() -> void:
	# 使用 call_deferred 确保 SceneTree 稳定后再挂载 CanvasLayer
	_create_effect_layer.call_deferred()


func _ready() -> void:
	_is_ready = true

	# 连接 EventBus 信号 (允许通过信号触发)
	if EventBus.has_signal("request_play_shatter"):
		EventBus.request_play_shatter.connect(_on_request_play_shatter)
		Logging.debug("%s: 已连接 EventBus.request_play_shatter" % LOG_TAG)
	else:
		Logging.warn("%s: EventBus 缺少 request_play_shatter 信号, 将仅支持直接调用" % LOG_TAG)

	Logging.info("%s: 初始化完成, CanvasLayer=%s layer=%d" % [
		LOG_TAG, EFFECT_LAYER_NAME, EFFECT_LAYER_INDEX
	])


func _exit_tree() -> void:
	# 断开信号连接
	if EventBus.has_signal("request_play_shatter") and EventBus.request_play_shatter.is_connected(_on_request_play_shatter):
		EventBus.request_play_shatter.disconnect(_on_request_play_shatter)

	# 清理特效层
	if _effect_layer != null and is_instance_valid(_effect_layer):
		_effect_layer.queue_free()
		_effect_layer = null

# ============================================================
# 工厂方法
# ============================================================

## 触发图片粉碎特效
## [param tex] 要粉碎的纹理
## [param global_pos] 特效发生的屏幕全局坐标
## [param duration] 动画持续秒数 (默认 1.0s)
## [param params] 可选 shader 参数覆盖 (如 {cell_size: 48.0})
func play_shatter(
	tex: Texture2D,
	global_pos: Vector2,
	duration: float = 1.0,
	params: Dictionary = {}
) -> void:
	if not _is_ready:
		Logging.warn("%s: 尚未 ready, 延迟执行 play_shatter" % LOG_TAG)
		await ready

	# ── 契约检查 ──────────────────────────────────────────
	if tex == null:
		Logging.err("%s: play_shatter 收到了空纹理, 拒绝执行 💀" % LOG_TAG)
		return

	if _effect_layer == null or not is_instance_valid(_effect_layer):
		Logging.err("%s: EffectLayer 不存在或已销毁, 无法创建特效 💀" % LOG_TAG)
		return

	# ── 实例化并初始化 ────────────────────────────────────
	var effect = SHATTER_SCENE.instantiate()
	_effect_layer.add_child(effect)
	# 使用 duck-typing 调用 initialize (避免 autoload 加载顺序导致 class_name 未注册)
	if effect.has_method("initialize"):
		effect.initialize(tex, global_pos, duration, params)
	else:
		Logging.err("%s: 特效场景缺少 initialize 方法 💀" % LOG_TAG)
		effect.queue_free()
		return

	Logging.info("%s: play_shatter → tex=%s pos=%s duration=%.2f" % [
		LOG_TAG, tex.resource_path, global_pos, duration
	])


# ============================================================
# 预留扩展点: 后续可添加其他特效
# ============================================================

# func play_fade(tex: Texture2D, pos: Vector2, duration: float) -> void:
# 	pass

# func play_pixelate(tex: Texture2D, pos: Vector2, duration: float) -> void:
# 	pass


# ============================================================
# 内部方法
# ============================================================

func _create_effect_layer() -> void:
	if _effect_layer != null:
		return # 已创建

	var root := get_tree().root
	if root == null:
		Logging.err("%s: SceneTree root 不可用, 无法创建 EffectLayer 💀" % LOG_TAG)
		return

	_effect_layer = CanvasLayer.new()
	_effect_layer.name = EFFECT_LAYER_NAME
	_effect_layer.layer = EFFECT_LAYER_INDEX
	root.add_child(_effect_layer)
	Logging.debug("%s: CanvasLayer 已创建并挂载到 root" % LOG_TAG)


func _on_request_play_shatter(tex: Texture2D, global_pos: Vector2, duration: float) -> void:
	play_shatter(tex, global_pos, duration)
