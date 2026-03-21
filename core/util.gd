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
	current_target_year: float   # 对应 self.next_point_year
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

# 核心函数：将原始无损颜色图转换为“纯索引 ID 图”
static func bake_index_map(original_img: Image, color_to_idx_dict: Dictionary) -> ImageTexture:
	Logging.info('start rebaking index map to machine index map')
	
	# 【防御性编程】强制统一内存格式，防止美术给你混入 RGB8 或带调色板的图 😡
	if original_img.get_format() != Image.FORMAT_RGBA8:
		original_img.convert(Image.FORMAT_RGBA8)
		
	var width = original_img.get_width()
	var height = original_img.get_height()
	
	# 直接提取连续内存块，放弃低效的像素级操作
	var src_data: PackedByteArray = original_img.get_data()
	var dst_data: PackedByteArray = PackedByteArray()
	dst_data.resize(src_data.size()) # 预分配同等大小的内存
	
	# ---------------------------------------------------------
	# 预处理：构建 O(1) 的整形哈希字典
	# 把 Hex 字符串翻译成 Int32 键值，拒绝在遍历中做任何对象分配！
	# ---------------------------------------------------------
	var int_lookup = {}
	for hex in color_to_idx_dict.keys():
		var c = Color.from_string(hex, Color.BLACK)
		var r8 = int(c.r * 255.0)
		var g8 = int(c.g * 255.0)
		var b8 = int(c.b * 255.0)
		# 用位移操作生成唯一 ID (r拼接到第16位，g拼接到第8位)
		var color_int = (r8 << 16) | (g8 << 8) | b8
		int_lookup[color_int] = color_to_idx_dict[hex]

	var match_count = 0
	var fail_count = 0
	var sample_fails = {} # 用字典去重记录失败颜色

	# ---------------------------------------------------------
	# 主循环：以 4 字节 (R, G, B, A) 为步长狂飙
	# ---------------------------------------------------------
	for i in range(0, src_data.size(), 4):
		var r = src_data[i]
		var g = src_data[i+1]
		var b = src_data[i+2]
		var a = src_data[i+3]
		
		# 背景过滤：Alpha < 13 约等于之前的 0.05
		if a < 13:
			# dst_data 默认是 0，可以不写，但显式写入防患于未然
			dst_data[i] = 0; dst_data[i+1] = 0; dst_data[i+2] = 0; dst_data[i+3] = 0
			continue
			
		# 计算当前像素的整数哈希
		var color_int = (r << 16) | (g << 8) | b
		
		if int_lookup.has(color_int):
			var best_id = int_lookup[color_int]
			# 写入索引：还原回 0-255 的字节写入
			dst_data[i] = int((float(best_id) / 512.0) * 255.0)
			dst_data[i+1] = 0
			dst_data[i+2] = 0
			dst_data[i+3] = 255 # Alpha 1.0 标识有效
			match_count += 1
		else:
			# 匹配失败：涂成纯白
			dst_data[i] = 255; dst_data[i+1] = 255; dst_data[i+2] = 255; dst_data[i+3] = 255
			fail_count += 1
			if sample_fails.size() < 5:
				# 记录真实的错误色值，方便你去痛骂上游 🤓☝️
				sample_fails["%02x%02x%02x" % [r, g, b]] = true

	# 一次性从内存块重建图像，优雅，高效 😭
	var processed_img = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, dst_data)

	# 纠错反馈循环
	print("--- [重焙审计报告 (内存狂飙版)] ---")
	print("字典大小: ", color_to_idx_dict.size())
	print("匹配成功像素: ", match_count)
	print("匹配失败像素: ", fail_count)
	if fail_count > 0:
		print("典型失败颜色样例 (Hex): ", sample_fails.keys())
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

static func apply_msg_type(msger: Messager, type: int): # int: MSG_TYPE
	"""
	给msger加上它对应的文字，图片，速度之类的效果
	"""
	var icon_path = ''
	var speed = 10
	var txt := ''

	match type:
		MSG_TYPE.CRITICAL:
			icon_path = 'msg_critical'
			speed = 30
			txt = Util.colorize('圣旨',Color.GOLD)
		MSG_TYPE.NORMAL:
			icon_path = 'msg_normal'
			txt = '消息'
		MSG_TYPE.TAX_WHEAT:
			icon_path = 'msg_tax_wheat'
			speed = 5
			txt = Util.colorize('粮税', Color.WHEAT)
		0:
			icon_path = 'msg_normal'
	
	var sprite = msger.get_node('MsgPathFollow/MsgSprite') as Sprite2D
	sprite.texture = IconLoader.get_icon(icon_path)
	msger.speed_px_per_sec = speed
	msger.txt = txt
			
static func add_colored_bg(color: Color, text: String):
	return '[bgcolor=%s]%s[/bgcolor]' % [color.to_html(),text]


static func create_dict(data: Array):
	var dict = {}
	for d in data:
		dict[d.uuid] = d
	return dict

static func create_dict_from_registry(registry: ResourceRegistry):
	"""
	从ResourceRegistry创建字典，使用registry中的resources字典
	registry: ResourceRegistry实例，包含resources字典
	"""
	var dict = {}
	if not registry or not registry.resources:
		return dict
	
	for uuid in registry.resources:
		var resource_path = registry.resources[uuid]
		var resource = load(resource_path)
		if resource:
			dict[uuid] = resource
		else:
			Logging.warn("无法加载资源: " + resource_path)
	
	return dict

static func strip_csv_array(data: Array):
	"""
	data: like "[a,b]"
	"""
	if data[0] is String:
		var d = data[0] as String
		d = d.lstrip("\"").rstrip("\"")
		d = d.lstrip("[").rstrip("]")
		var result = d.split(',')
		var float_res = []
		float_res.append(float(result[0]))
		float_res.append(float(result[1]))
		return float_res
	return data
		
