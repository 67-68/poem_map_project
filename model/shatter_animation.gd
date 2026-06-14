class_name ShatterAnimation extends AnimationObject

const SHATTER_SHADER := preload("res://shaders/image_shatter.gdshader")

var _sprite: Sprite2D
var _duration: float
var _params: Dictionary

func _init(sprite: Sprite2D, duration: float, params: Dictionary = {}):
	_sprite = sprite
	_duration = duration
	_params = params

func start() -> void:
	if not _sprite or not is_instance_valid(_sprite):
		Logging.warn("ShatterAnimation: sprite 已失效")
		return
	is_playing = true
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SHATTER_SHADER
	shader_mat.set_shader_parameter("progress", 0.0)
	for key in _params:
		if shader_mat.get_shader_parameter(key) != null:
			shader_mat.set_shader_parameter(key, _params[key])
	_sprite.material = shader_mat

	_kill_tween()
	_tween = _sprite.create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_update_shader_progress.bind(shader_mat), 0.0, 1.0, _duration)
	_tween.finished.connect(_on_finished)

func _update_shader_progress(val: float, mat: ShaderMaterial) -> void:
	if mat != null:
		mat.set_shader_parameter("progress", val)

func _on_finished() -> void:
	is_playing = false
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	finished.emit()
