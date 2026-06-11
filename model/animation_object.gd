class_name AnimationObject extends RefCounted
## 时间驱动的舞台动画基类
## 所有需要时间呈现的视觉效果继承此类。
## NarrativeOverlay 持有当前活跃的 AnimationObject 列表，独立于事件队列管理。
## 每个 AnimationObject 内部使用 Tween 驱动，且强制 TWEEN_PAUSE_PROCESS，
## 确保在世界暂停时动画仍能继续播放。

signal finished

var is_playing: bool = false
var _tween: Tween

# 子类必须 override
func start() -> void:
	push_error("AnimationObject.start() 未实现")

func stop() -> void:
	_kill_tween()
	is_playing = false

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
