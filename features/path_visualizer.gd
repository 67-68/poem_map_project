class_name PathVisualizer extends Node

static func get_bezier_path(p1_id: String, p2_id: String, x, y) -> Curve2D:
	# 从单例获取路径 ID 序列
	var node_indices = NavigationService.get_index_id_path(p1_id, p2_id)
	if node_indices.size() < 2: return null
	
	var curve := Curve2D.new()
	var map_size = Vector2(x, y)
	
	for i in range(node_indices.size() - 1):
		# 获取当前节点和下一个节点的省份 ID
		var curr_id = NavigationService.get_province_id_from_idx(node_indices[i])
		var next_id = NavigationService.get_province_id_from_idx(node_indices[i+1])
		
		var start_pos = Global.base_province[curr_id].uv_position * map_size
		var end_pos = Global.base_province[next_id].uv_position * map_size

		# 手动使用魔法数据处理一下
		start_pos.y += 40
		end_pos.y += 40
		
		# 每一段路径：起点 -> 扰动点 -> 终点
		# 注意：Curve2D 会自动处理连接，不需要重复添加起点
		if i == 0:
			curve.add_point(start_pos)
		
		# 插入带有“扰动”的中间点
		var noise_pos = _create_noise_point(start_pos, end_pos)
		curve.add_point(noise_pos)
		
		# 添加该段的终点
		curve.add_point(end_pos)
	
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
