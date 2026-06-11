class_name ShatterEffect extends Node2D

# ── 日志标签 ──────────────────────────────────────────────
const LOG_TAG := "ShatterEffect"

# ── 节点引用 ──────────────────────────────────────────────
@onready var _sprite: Sprite2D = $Sprite2D

# ── 状态 ──────────────────────────────────────────────────
var _is_playing := false

# ============================================================
# 公共接口
# ============================================================

## 初始化并播放碎裂特效
## [param tex] 要粉碎的纹理
## [param pos] 特效全局位置 (屏幕坐标)
## [param duration] 动画持续秒数
## [param params] 可选 shader 参数覆盖
func initialize(
	tex: Texture2D,
	pos: Vector2,
	duration: float = 1.0,
	params: Dictionary = {}
) -> void:
	# ── 契约检查 ──────────────────────────────────────────
	assert(tex != null, "%s: texture 为空, 碎个寂寞 💀" % LOG_TAG)
	if tex == null:
		Logging.err("%s: texture is null, aborting" % LOG_TAG)
		queue_free()
		return

	# ── 设置纹理和位置 ────────────────────────────────────
	_sprite.texture = tex
	global_position = pos

	# ── 设置 Shader 参数 ─────────────────────────────────
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		Logging.err("%s: Sprite2D 没有挂 ShaderMaterial 💀" % LOG_TAG)
		queue_free()
		return

	# 默认值
	mat.set_shader_parameter("progress", 0.0)

	# 覆盖自定义参数
	for key in params:
		if mat.get_shader_parameter(key) != null:
			mat.set_shader_parameter(key, params[key])
		else:
			Logging.warn("%s: 未知 shader 参数 '%s', 跳过" % [LOG_TAG, key])

	# ── Tween 动画 ────────────────────────────────────────
	_is_playing = true

	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_update_progress, 0.0, 1.0, duration)
	tw.finished.connect(_on_finished)

	Logging.debug("%s: start → tex=%s pos=%s duration=%.2f" % [
		LOG_TAG, tex.resource_path, pos, duration
	])

# ============================================================
# 内部方法
# ============================================================

func _update_progress(val: float) -> void:
	var mat := _sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("progress", val)


func _on_finished() -> void:
	_is_playing = false
	Logging.debug("%s: finished, queue_free" % LOG_TAG)
	queue_free()
