class_name PathVisualizer extends Node

static func get_bezier_path(p1_id: String, p2_id: String, x: float, y: float) -> Curve2D:
	var node_indices = NavigationService.get_index_id_path(p1_id, p2_id)
	if node_indices.size() < 2: return null
	
	var curve := Curve2D.new()
	var map_size = Vector2(x, y)
	
	# 只需要添加所有的路点，利用控制点来做平滑和扰动
	for i in range(node_indices.size()):
		var curr_id = NavigationService.get_province_id_from_idx(node_indices[i])
		var pos = Global.base_province[curr_id].uv_position * map_size
		pos.y += 40
		
		# 计算控制点 (Handle)
		# 我们不加中间点，而是给当前点加一个“出射向量”和一个“入射向量”
		var control_in = Vector2.ZERO
		var control_out = Vector2.ZERO
		
		# 如果你想要扰动，不是去改变点的位置，而是去扭曲控制杆
		if Global.PATH_NOISE > 0:
			# 生成一个垂直于路径方向的随机向量会更自然，但这比较复杂
			# 简单做法：给控制点加随机偏移
			var noise = Vector2(
				randf_range(-Global.PATH_NOISE, Global.PATH_NOISE),
				randf_range(-Global.PATH_NOISE, Global.PATH_NOISE)
			)
			# 让控制点稍微偏离中心
			control_in = -noise * 50.0 # 入射杆
			control_out = noise * 50.0 # 出射杆
		
		# 如果想要更圆润，应该根据前后点计算切线，这里先用简单噪点演示
		
		curve.add_point(pos, control_in, control_out)
		
	return curve

static func _create_noise_point(p1: Vector2, p2: Vector2) -> Vector2:
	var mid = (p1 + p2) / 2.0
	# 修复：你之前的写法会把坐标直接重置到 (0-Noise) 范围内
	# 应该是基于中点进行偏移 (Offset)
	var offset = Vector2(
		randf_range(-Global.PATH_NOISE, Global.PATH_NOISE),
		randf_range(-Global.PATH_NOISE, Global.PATH_NOISE)
	)
	return mid + offset
