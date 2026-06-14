class_name FadeOutAnimation extends AnimationObject

var _sprite: Sprite2D
var _duration: float

func _init(sprite: Sprite2D, duration: float):
	_sprite = sprite
	_duration = duration

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		Logging.warn("FadeOutAnimation: sprite 已失效")
		return
	is_playing = true
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_sprite, "modulate:a", 0.0, _duration)
	_tween.finished.connect(_on_finished)

func _on_finished() -> void:
	is_playing = false
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	finished.emit()
