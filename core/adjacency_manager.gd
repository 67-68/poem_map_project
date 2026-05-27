class_name AdjacencyManager extends RefCounted

# 3. 增强版扫描算法（解决厚边框问题）
# 原理：不是看一眼隔壁，而是“发射射线”直到撞到别人
static func robust_scan(index_img: Image, color_2_id: Dictionary, max_border_thickness: int = 5) -> Dictionary:
	var connections = {}
	var w = index_img.get_width()
	var h = index_img.get_height()
	
	# 仍然可以用 step 跳跃来优化性能，但检测逻辑要变
	var step = 4 
	
	for y in range(0, h, step):
		for x in range(0, w, step):
			var pix = index_img.get_pixel(x,y)
			if pix.a < 0.1: continue
			
			var current_id = color_2_id.get(pix.to_html(false))
			if not current_id: continue # 踩在边框上了，跳过
			 
			# 向右发射射线
			_cast_ray(index_img, x, y, 1, 0, current_id, color_2_id, connections, max_border_thickness)
			# 向下发射射线
			_cast_ray(index_img, x, y, 0, 1, current_id, color_2_id, connections, max_border_thickness)
			
	return connections

# 射线检测辅助函数
static func _cast_ray(img: Image, start_x: int, start_y: int, dir_x: int, dir_y: int, 
					current_id: String, color_map: Dictionary, out_conn: Dictionary, max_dist: int):
	for i in range(1, max_dist + 1):
		var dx = start_x + dir_x * i
		var dy = start_y + dir_y * i
		
		if dx >= img.get_width() or dy >= img.get_height(): break
		
		var p_next = img.get_pixel(dx, dy)
		
		# 如果是透明区域，可能还没跨过海峡/边界，继续找
		if p_next.a < 0.1: continue 
		
		var next_id_hex = p_next.to_html(false)
		var next_id = color_map.get(next_id_hex)
		
		# 撞到边框色（不在map里的颜色），继续穿透
		if not next_id: continue 
		
		if next_id != current_id:
			# 只要撞到第一个不是自己的有效ID，就是邻居
			_add_connection(out_conn, current_id, next_id)
			return # 找到邻居就停止，防止穿透到隔壁的隔壁
		else:
			# 还是自己，不用管
			pass

static func _add_connection(dict: Dictionary, a: String, b: String):
	if not dict.has(a): dict[a] = []
	if not dict.has(b): dict[b] = []
	if not b in dict[a]: dict[a].append(b)
	if not a in dict[b]: dict[b].append(a)