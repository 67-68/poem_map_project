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
		if Global.base_provinces.has(id):
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
	
	# 2. 从注册表获取实体数据
	var entity = Global.territory_registry.get(current_id)
	if not entity:
		# 如果注册表里没有，它可能就是一个原始州 ID，先放进结果集待查
		result_set[current_id] = true
		return
	
	# 3. 检查是否有子单位 (sub_territory_ids)
	if entity.sub_territory_ids.size() > 0:
		# 它是一个容器（道/节度使），递归处理其子项
		for sub_id in entity.sub_territory_ids:
			_explode_recursive(sub_id, result_set, visited)
	else:
		# 它是一个原子单位，记录下来
		result_set[current_id] = true

# --- 架构师的性能优化建议 ---
# 如果你的行政树很深，建议在 Global 中对常用的“道/节度使”结果进行缓存 (Memoization)。
# 否则每次点击“大唐中央”都要递归几百次，你的 CPU 会像在三伏天赶路的差役一样中暑。🤣