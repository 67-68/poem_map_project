extends Node

## @deprecated 请改用 ImageManager + ImageHandle
##
## 此模块保留用于向后兼容, 所有方法转发到 ImageManager.
## 新代码请直接使用:
##   ImageManager.present(tex, uv)          → 返回 ImageHandle
##   ImageManager.play_shatter(tex, uv)
##   ImageManager.play_slide(tex, from_uv, to_uv)

const LOG_TAG := "ImageEffectManager"

func _ready() -> void:
	Logging.warn("%s: 已废弃, 请改用 ImageManager" % LOG_TAG)
	# 连接 EventBus 信号转发到 ImageManager
	if EventBus.has_signal("request_play_shatter"):
		if not EventBus.request_play_shatter.is_connected(_on_request_play_shatter):
			EventBus.request_play_shatter.connect(_on_request_play_shatter)


func play_shatter(tex: Texture2D, uv: Vector2, duration: float = 1.0, params: Dictionary = {}) -> void:
	Logging.warn("%s: 已废弃, 请改用 ImageManager.play_shatter()" % LOG_TAG)
	ImageManager.play_shatter(tex, uv, duration, params)


func _on_request_play_shatter(tex: Texture2D, uv: Vector2, duration: float) -> void:
	play_shatter(tex, uv, duration)


func _exit_tree() -> void:
	if EventBus.has_signal("request_play_shatter") and EventBus.request_play_shatter.is_connected(_on_request_play_shatter):
		EventBus.request_play_shatter.disconnect(_on_request_play_shatter)
