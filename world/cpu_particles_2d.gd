extends CPUParticles2D

# 暂时直接连接信号
func on_request_rain(enable: bool):
	if enable:
		emitting = true
	else:
		emitting = false

func _ready() -> void:
	Global.request_rain.connect(on_request_rain)

func _process(delta: float) -> void:
	pass
