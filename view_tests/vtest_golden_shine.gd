class_name DebugGoldenShine extends RefCounted

var view: Control


func create_debug_view(idx: int) -> Control:
	match idx:
		0:
			var btn := _make_shine_button(tr("CODE_VTEST_GOLDEN_SHINE_EF622DDDC0"), Color(0.9, 0.75, 0.1))
			btn.custom_minimum_size = Vector2(180, 60)
			btn.size = Vector2(180, 60)
			return btn
		1:
			var btn := _make_shine_button(tr("CODE_VTEST_GOLDEN_SHINE_E56FE50456"), Color(1.0, 0.85, 0.0))
			btn.custom_minimum_size = Vector2(220, 80)
			btn.size = Vector2(220, 80)
			return btn
		2:
			var btn := _make_shine_button(tr("CODE_VTEST_GOLDEN_SHINE_2C4C6284D0"), Color(0.95, 0.7, 0.05))
			btn.custom_minimum_size = Vector2(200, 70)
			btn.size = Vector2(200, 70)
			return btn
		3:
			var btn := _make_shine_button(tr("CODE_VTEST_GOLDEN_SHINE_06FFA726CD"), Color(1.0, 0.8, 0.2))
			btn.custom_minimum_size = Vector2(200, 60)
			btn.size = Vector2(200, 60)
			return btn
		_:
			return null


func _make_shine_button(text: String, modulate_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.modulate = modulate_color

	# 加载 golden_shine shader 并创建 ShaderMaterial
	var shader := load("res://shaders/golden_shine.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.resource_local_to_scene = true
	# 默认参数即可驱动呼吸，此处可覆写
	mat.set_shader_parameter("speed", 1.2)
	mat.set_shader_parameter("intensity", 0.35)
	mat.set_shader_parameter("gold_color", Color(1.0, 0.843, 0.0, 1.0))
	mat.set_shader_parameter("highlight_color", Color(1.0, 0.95, 0.6, 1.0))

	btn.material = mat
	btn.pressed.connect(func(): Logging.info("[GoldenShineTest] 按钮被点击: %s" % text))

	return btn


func get_actions() -> Array[ViewTestAction]:
	return [
		ViewTestAction.new('点击任意按钮查看呼吸金光', func(_map: Dictionary): pass),
	]
