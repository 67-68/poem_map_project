class_name Util extends RefCounted

static func get_highest_val_from_dict_vec2(dict: Dictionary, axis: int) -> float:
	var max_val: float = 0.0
	for val in dict.values():
		if val is Vector2:
			# axis 传入 0 代表 x, 1 代表 y
			max_val = maxf(max_val, val[axis])
	return max_val

static func get_margin_left_right(obj):
	return obj.get_theme_constant('margin_left') + obj.get_theme_constant('margin_right')

static func colorize(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(), text]

static func underline(text: String) -> String:
	return "[u]%s[/u]" % text

static func link(text: String, key: String) -> String:
	return "[url=%s]%s[/url]" % [key, text]

static func colorize_underlined_link(text: String,color: Color,key: String):
	return colorize(underline(link(text,key)),color)

static func process_poem_events(
	points_data: Dictionary,   # 对应 Global.life_path_points
	path_keys: Array,          # 对应 datamodel.path_point_keys (必须是有序的！)
	current_target_year: int   # 对应 self.next_point_year
) -> PoemProcessResult:
	
	var result = PoemProcessResult.new()
	result.new_target_year = current_target_year # 默认保持不变
	
	var found_current = false
	
	for p in path_keys:
		var point_data = points_data.get(p)
		if not point_data: continue
		
		var year = point_data.year
		
		# 1. 寻找当前年份的诗词
		if not found_current and year == current_target_year:
			var tags = point_data.tags
			for t in tags:
				if t.begins_with("poem") and not t.ends_with("creation"):
					result.poems_to_emit.append(t.substr(5))
			
			if not result.poems_to_emit.is_empty():
				result.found_poems = true
				found_current = true # 标记已处理，防止重复
		
		# 2. 寻找下一年的路标 (这是修复死循环的关键 🤓☝️)
		# 只有当这一年的年份确实大于当前目标年份时，我们才更新目标
		if year > current_target_year:
			# 如果我们还没找到下一个目标，或者这个年份比我们暂存的下一个目标更近
			if result.new_target_year == current_target_year or year < result.new_target_year:
				result.new_target_year = year
				# 找到了最近的下一年，不需要 break，继续找可能还有同年的点？
				# 通常如果 keys 是按时间排序的，这里可以直接 break。
				# 假设 keys 顺序不可靠，我们得遍历完以找到最小的大于 current 的值
	
	return result

static func geo_to_pixel(lon: float, lat: float) -> Vector2:
	var x = (lon - Global.LON_MIN) / (Global.LON_MAX - Global.LON_MIN) * Global.MAP_WIDTH
	# 别忘了 Y 轴是反的，除非你想让李白飞到天上去 💀
	var y = (1.0 - (lat - Global.LAT_MIN) / (Global.LAT_MAX - Global.LAT_MIN)) * Global.MAP_HEIGHT
	return Vector2(x, y)

static func pixel_to_geo(pos: Vector2) -> Array:
	var lon = (pos.x / Global.MAP_WIDTH) * (Global.LON_MAX - Global.LON_MIN) + Global.LON_MIN
	var lat = (1.0 - (pos.y / Global.MAP_HEIGHT)) * (Global.LAT_MAX - Global.LAT_MIN) + Global.LAT_MIN
	return [lon, lat]



# 核心算法：获取所有相关的原子州 ID
# @param input_ids: 用户提供的 ID 列表（可以是州、道、势力等）
# @return: 一个去重后的原子州 ID 数组
static func resolve_to_provinces(input_ids: Array) -> Array[String]:
	var result_set = {} # 使用 Dictionary 模拟 Set，实现 O(1) 去重
	var visited = {}    # 防止循环引用导致的栈溢出 💀
	
	for id in input_ids:
		_explode_recursive(id, result_set, visited)
	
	# 最后一步：白名单过滤
	# 只有在 Global.base_provinces 中存在的才保留
	var final_list: Array[String] = []
	for id in result_set.keys():
		if Global.base_province.has(id):
			final_list.append(id)
		else:
			# 这种通常是因为你传入了一个逻辑单位（如“范阳”），它本身不是地块
			# 我们只需要它的子集，不需要它自己，所以这里直接略过
			pass
			
	return final_list

# 内部递归函数
static func _explode_recursive(current_id: String, result_set: Dictionary, visited: Dictionary):
	# 1. 基础防御：如果已经处理过，直接跳过
	if visited.has(current_id): return
	visited[current_id] = true
	
	# 2. 从注册表获取实体数据. 这里的注册表指的是Territory而不是BaseProvince
	var entity = Global.territories.get(current_id)
	if not entity:
		# 如果注册表里没有，它可能就是一个原始州 ID，先放进结果集待查
		result_set[current_id] = true
		return
	
	# 3. 检查是否有子单位 (sub_territory_ids)
	if entity.sub_ids.size() > 0:
		# 它是一个容器（道/节度使），递归处理其子项
		for sub_id in entity.sub_ids:
			_explode_recursive(sub_id, result_set, visited)
	else:
		# 它是一个原子单位，记录下来
		result_set[current_id] = true

# 核心函数：将原始乱序颜色图转换为“纯索引 ID 图”
static func bake_index_map(original_img: Image, color_to_idx_dict: Dictionary) -> ImageTexture:
	var width = original_img.get_width()
	var height = original_img.get_height()
	var processed_img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var match_count = 0
	var fail_count = 0
	var sample_fails = [] # 记录前几个失败的颜色

	var lookup = []
	for hex in color_to_idx_dict.keys():
		lookup.append({
			"c": Color.from_string(hex, Color.BLACK), 
			"id": color_to_idx_dict[hex], 
			"hex": hex
		})

	for y in range(height):
		for x in range(width):
			var p = original_img.get_pixel(x, y)
			
			# 背景过滤：透明度太低或者几乎纯黑且透明的像素直接过
			if p.a < 0.05:
				processed_img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue 
			
			var best_id = -1
			# 容差阈值 (0.15 左右通常能过滤掉 JPG 明显的压缩噪声)
			var threshold = 0.005
			
			for entry in lookup:
				# 手动计算 RGB 空间的距离 (Euclidean Distance)
				var r_diff = p.r - entry.c.r
				var g_diff = p.g - entry.c.g
				var b_diff = p.b - entry.c.b
				var dist = sqrt(r_diff*r_diff + g_diff*g_diff + b_diff*b_diff)
				
				if dist < threshold:
					best_id = entry.id
					break
			
			if best_id != -1:
				# 写入索引：ID / 512.0 (确保 360 个州都在 0-1 范围内)
				# Alpha 设为 1.0 是为了让 Shader 的 mask 能够识别出这是有效像素
				processed_img.set_pixel(x, y, Color(float(best_id)/512.0, 0, 0, 1.0))
				match_count += 1
			else:
				# 匹配失败：涂成纯白 (1, 1, 1, 1)
				# 这样你在调试 Shader 的 mode 1 时，看到的白色斑块就是“没对上号”的州
				processed_img.set_pixel(x, y, Color(1, 1, 1, 1))
				fail_count += 1
				if sample_fails.size() < 5:
					sample_fails.append(p.to_html(false))

	print("--- [重焙审计报告] ---")
	print("字典大小: ", color_to_idx_dict.size())
	print("匹配成功像素: ", match_count)
	print("匹配失败像素: ", fail_count)
	if fail_count > 0:
		print("典型失败颜色样例: ", sample_fails)
	print("----------------------")
	
	return ImageTexture.create_from_image(processed_img)

static func save_to(data,path):
	"""
	父路径需要首先存在
	"""
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_var(data)
	Logging.info('存储 %s 到了 %s' % [data,path])

static func get_mesh_instance_size(mesh_inst: MeshInstance2D) -> Vector3:
	var siz = mesh_inst.mesh.get_aabb().size
	siz.x *= mesh_inst.scale.x
	siz.y *= mesh_inst.scale.y
	return siz