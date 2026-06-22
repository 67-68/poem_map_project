@tool
extends Node2D

const LOG_TAG := "FrostEffect"

@onready var _sprite: Sprite2D = $Sprite2D

var _is_playing := false
var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 运行时自动循环演示
	_play_loop()


func _play_loop() -> void:
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		return

	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_update_freeze, 0.0, 1.0, 3.0)
	tw.tween_interval(0.8)
	tw.tween_method(_update_freeze, 1.0, 0.0, 2.0)
	tw.tween_interval(0.5)
	tw.set_loops()
	_is_playing = true


func play_frost(duration: float = 3.0) -> void:
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_is_playing = true
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_update_freeze, 0.0, 1.0, duration)


func reset_frost() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		var mat := _sprite.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("freeze_progress", 0.0)
		_is_playing = false


func _update_freeze(val: float) -> void:
	var mat := _sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("freeze_progress", val)
