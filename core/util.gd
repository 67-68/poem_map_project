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
	points_data: Dictionary,   # 对应 Database.life_path_points
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
	var x = (lon - GameConfig.LON_MIN) / (GameConfig.LON_MAX - GameConfig.LON_MIN) * GameConfig.MAP_WIDTH
	# 别忘了 Y 轴是反的，除非你想让李白飞到天上去 💀
	var y = (1.0 - (lat - GameConfig.LAT_MIN) / (GameConfig.LAT_MAX - GameConfig.LAT_MIN)) * GameConfig.MAP_HEIGHT
	return Vector2(x, y)

static func pixel_to_geo(pos: Vector2) -> Array:
	var lon = (pos.x / GameConfig.MAP_WIDTH) * (GameConfig.LON_MAX - GameConfig.LON_MIN) + GameConfig.LON_MIN
	var lat = (1.0 - (pos.y / GameConfig.MAP_HEIGHT)) * (GameConfig.LAT_MAX - GameConfig.LAT_MIN) + GameConfig.LAT_MIN
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
		if Database.get_province(id) != null:
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
	var entity = Database.get_territory(current_id)
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
	Logging.info("--- [重焙审计报告 (内存狂飙版)] ---")
	Logging.info("字典大小:  %s" % [color_to_idx_dict.size()])
	Logging.info("匹配成功像素:  %s" % [match_count])
	Logging.info("匹配失败像素:  %s" % [fail_count])
	if fail_count > 0:
		Logging.info("典型失败颜色样例 (Hex):  %s" % [sample_fails.keys()])
	Logging.info("----------------------")
	
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
	sprite.texture = TextureResLoader.get_icon(icon_path)
	msger.speed_px_per_sec = speed
	msger.txt = txt
			
static func add_colored_bg(color: Color, text: String):
	return '[bgcolor=%s]%s[/bgcolor]' % [color.to_html(),text]


static func create_dict(data: Array):
	var dict = {}
	for d in data:
		dict[d.uuid] = d
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
# 合并 context 字典：将 overlay 中的自定义参数合并到 base 中
# 规则：
#   - int/float 类型：base[key] *= overlay[key]（相乘）
#   - String 类型：尝试 to_float() 转换，成功则按乘法叠加（数值 context 相乘），失败则直接存为字符串值
#     （因为 DSL 解析出的 custom_params 中可能存在非数值描述字段，必须携带过去，不能 drop）
#   - Array / PackedStringArray 类型：直接覆盖（数组作为 opaque 值传递，不尝试数学运算）
#   - 其他类型：breakpoint + push_error "not implemented"
static func merge_context(base: Dictionary, overlay: Dictionary) -> Dictionary:
	if overlay.is_empty():
		return base
	
	for key in overlay:
		var overlay_val = overlay[key]
		var base_val = base.get(key)
		
		# --- String 类型处理 ---
		# DSL 解析出的 custom_params 全是字符串，需要区分"数字字符串"和"文本字符串"
		if overlay_val is String:
 			#breakpoint
			var float_val = overlay_val.to_float()
			var is_numeric = float_val != 0.0 or overlay_val == "0" or overlay_val == "0.0"
			
			if is_numeric:
				# 能转数字 → 按数值乘法叠加（或覆盖）
				Logging.info("merge_context: 数值字符串合并. key=%s, value=%s" % [key, overlay_val])
				if base_val is int or base_val is float:
					base[key] = base_val * float_val
				else:
					# base 中没有/非数值 → 直接存浮点数
					base[key] = float_val
			else:
				# 不能转数字 → 直接存字符串（携带文本描述字段，不能 drop）
				Logging.info("merge_context: 文本字符串合并. key=%s, value=%s" % [key, overlay_val])
				base[key] = overlay_val
			
			continue  # String 处理完毕，跳到下一个 key
		
		# --- int/float 类型处理 ---
		if overlay_val is int or overlay_val is float:
			if base_val is int or base_val is float:
				base[key] = base_val * overlay_val
			else:
				base[key] = overlay_val
			continue
		
		# --- Array / PackedStringArray 类型处理 ---
		# DSL 解析出的 [a;b;c] 数组，直接覆盖（opaque 值，不尝试数学运算）
		if overlay_val is Array or overlay_val is PackedStringArray:
			Logging.info("merge_context: 数组合并. key=%s, value=%s" % [key, str(overlay_val)])
			base[key] = overlay_val
			continue
		
		# --- 其他类型 → 报错（未实现） ---
		Logging.err("merge_context: 未实现的 overlay 类型合并. key=%s, type=%s, value=%s" % [key, typeof(overlay_val), str(overlay_val)])
	
	return base


# ──────────────────────────────────────────────
# 动态差值系统：将文本中的占位符替换为实际值
# ──────────────────────────────────────────────
# {some_prop}   → 从 instance 对象上获取属性（如 self.some_prop）
# {@some_prop}  → 从 context 字典中获取值
#
# 找不到时保留原占位符（debug 透明，不会静默吞错误 💀）
#
# 使用场景：
#   EventOption.description 中写入 "{@target_npc}"，init() 时自动替换为 context 中的实际值
#
# @param text:     包含占位符的原始文本
# @param context:  运行时字典（通常由 DSL 解析 + merge_context 产生）
# @param instance: 调用方对象（例如 self），用于 {prop} 类占位符查找
# @return:         替换后的文本
# ──────────────────────────────────────────────
static func resolve_template(text: String, context: Dictionary, instance: Object) -> String:
	if text.is_empty():
		return text
	
	var regex = RegEx.new()
	regex.compile("\\{(@?)(\\w+)\\}")
	
	var result = text
	var matches = regex.search_all(text)
	
	# 反向遍历，避免替换位置偏移
	for i in range(matches.size() - 1, -1, -1):
		var match = matches[i]
		var has_at = match.get_string(1) == "@"
		var prop_name = match.get_string(2)
		var start = match.get_start()
		var end = match.get_end()
		var replacement = ""
		
		if has_at:
			# {@some_prop} → 从 context 字典查找
			if context.has(prop_name):
				replacement = str(context[prop_name])
			else:
				Logging.warn("[resolve_template] context 中找不到键 '%s'，保留占位符" % prop_name)
				replacement = match.get_string()  # 保留原样，方便 debug
		else:
			# {some_prop} → 从 instance 对象查找
			if instance and prop_name in instance:
				replacement = str(instance[prop_name])
			else:
				Logging.warn("[resolve_template] instance 上找不到属性 '%s'，保留占位符" % prop_name)
				replacement = match.get_string()  # 保留原样，方便 debug
		
		# 通过拼接替换（避免 replace() 全部替换的副作用）
		result = result.left(start) + replacement + result.substr(end)
	
	return result


# ──────────────────────────────────────────────
# 翻译 + 动态插值：tr() 查表 + 模板解析 串联
# ──────────────────────────────────────────────
# 流程：
#   1. 如果是 CONSTANT（全大写，如 CHOOSE_TARGET）→ tr() 查翻译表
#   2. 普通文本跳过步骤 1
#   3. 统一检查结果中是否有 {@key}/{key} 占位符 → resolve_template 插值
#   4. 插值结果不再递归 tr()
#
# @param text:     原始文本（可能是翻译 key，也可能是带占位符的普通文本）
# @param context:  运行时字典，用于 {@key} 插值
# @param instance: 调用方对象，用于 {key} 插值
# @return:         最终展示文本
# ──────────────────────────────────────────────
static func tr_and_resolve(text: String, context: Dictionary, instance: Object) -> String:
	if text.is_empty():
		return text
	
	# Step 1: CONSTANT → tr() 查表翻译
	var result = text
	if _is_constant_key(text):
		result = TranslationServer.translate(text)
		Logging.info("[tr_and_resolve] tr('%s') → '%s'" % [text, result])
	
	# Step 2: 统一检查占位符并插值（无论是否经过翻译）
	if not result.is_empty() and "{" in result:
		result = resolve_template(result, context, instance)
	
	return result


# 判断是否为 CONSTANT 翻译 key（全大写，允许数字和下划线）
static func _is_constant_key(text: String) -> bool:
	if text.is_empty():
		return false
	
	for i in text.length():
		var c = text[i]
		var code = c.unicode_at(0)
		# 允许：A-Z (65-90), _ (95), 0-9 (48-57)
		if not ((code >= 65 and code <= 90) or code == 95 or (code >= 48 and code <= 57)):
			return false
	
	return true
