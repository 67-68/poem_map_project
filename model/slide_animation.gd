class_name SlideAnimation extends AnimationObject

var _sprite: Sprite2D
var _target_pos: Vector2
var _duration: float

func _init(sprite: Sprite2D, target_pos: Vector2, duration: float):
	_sprite = sprite
	_target_pos = target_pos
	_duration = duration

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		push_warning("SlideAnimation: sprite 已失效")
		return
	is_playing = true
	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_sprite, "global_position", _target_pos, _duration) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.finished.connect(_on_finished)

func _on_finished() -> void:
	is_playing = false
	finished.emit()
