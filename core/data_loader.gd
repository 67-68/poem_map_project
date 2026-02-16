# ----------------------------------------------------------------
# 大唐地理系统 - 高性能数据加载器 (DataLoader)
# ----------------------------------------------------------------
# 资深架构师评价：CSV 是极其务实的选择，它比臃肿的 JSON 更适合存那 360 个州。
# 这里的逻辑是将“扁平的表格”转化为“立体的对象”。
# ----------------------------------------------------------------
extends RefCounted

class_name DataLoader

# 内部路径修正工具
static func _fix_path(file_path: String, extension: String, global_path: String) -> String:
	if not file_path.begins_with("res://") and not file_path.begins_with("user://"):
		# 假设 Global.DATA_PATH 已经定义好，且以 / 结尾
		file_path = global_path + file_path
	if not file_path.ends_with(extension):
		file_path += "." + extension
	return file_path

# 原有的 JSON 加载逻辑 (稍作封装)
static func load_json_model(model_class: Variant, file_path: String) -> Array:
	file_path = _fix_path(file_path, "json",Global.DATA_PATH)
	
	if not FileAccess.file_exists(file_path):
		printerr("💀 JSON 丢失！文件路径：", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	
	if content == null:
		printerr("😡 JSON 格式错误，请检查语法：", file_path)
		return []
		
	var result: Array = []
	# 容错处理：如果 JSON 只有单个对象而不是数组，包装成数组
	var items = content if content is Array else [content]

	# --- [插入点 1] ---
	# 架构师留言：预热哈希表，别在循环里瞎反射 💀
	var dummy_instance = model_class.new({})
	var valid_keys = {}
	for prop in dummy_instance.get_property_list():
		valid_keys[prop["name"]] = true
	# -----------------

	for item in items:
		# --- [插入点 2] ---
		# 架构师留言：让脏数据无处遁形 😡
		for key in item.keys():
			if not valid_keys.has(key) and key != 'properties':
				Logging.warn("😨 幽灵字段出没！JSON 键 '%s' 在数据模型 %s 中不存在。请检查拼写或更新你的 Resource 结构。(文件: %s)" % [key, model_class, file_path])
		# -----------------
		
		# (这是你原有的代码)
		result.append(model_class.new(item))
	
	Logging.info('load %s model %s from %s' % [result.size(),model_class,file_path])
	return result

static func load_csv_model(model_class: Variant, file_path: String) -> Array:
	file_path = _fix_path(file_path, "csv", Global.PERMANENT_DATA_PATH)
	if not FileAccess.file_exists(file_path):
		printerr("😨 CSV 档案被次元放逐了！路径：", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var result: Array = []
	var headers = file.get_csv_line()
	
	# --- [拦截网预热] ---
	# 架构师留言：动态获取 Resource 真实拥有的属性，消灭硬编码！
	var dummy_instance = model_class.new({})
	var valid_keys = {}
	for prop in dummy_instance.get_property_list():
		valid_keys[prop["name"]] = true
	# --------------------

	while !file.eof_reached():
		var line = file.get_csv_line()
		# 容错：空行或纯注释行直接跳过
		if line.size() == 0 or line[0].strip_edges() == "" or (line[0].begins_with("#") and line.size() == 1):
			continue
		
		var raw_data = {}
		for i in range(headers.size()):
			if i >= line.size(): 
				continue # 防御性编程：防止 CSV 格式不齐导致的越界崩溃
			
			var key = headers[i].strip_edges()
			var val = line[i].strip_edges()
			
			# 处理数组逻辑: [a;b;c] -> Array
			if val.begins_with("[") and val.ends_with("]"):
				var content = val.substr(1, val.length() - 2)
				val = Array(content.split(";", false)) 
			
			raw_data[key] = val

		# --- 数据归一化逻辑 (Normalization) ---
		var entity_data = {"properties": {}}
		
		# 1. 坐标聚合：修复了你那逆天的 uv_x == uv_x 的 bug 💀
		if raw_data.has("uv_x") and raw_data.has("uv_y"):
			entity_data["uv_position"] = Vector2(float(raw_data.uv_x), float(raw_data.uv_y))
			raw_data.erase("uv_x") # 清理现场
			raw_data.erase("uv_y")
		elif raw_data.has("x") and raw_data.has("y"):
			entity_data["position"] = Vector2(float(raw_data.x), float(raw_data.y))
			Logging.warn('使用正常 position 加载了数据，请确认数据中的 position 是符合游戏的')
			raw_data.erase("x")
			raw_data.erase("y")
		
		# 2. 动态字段分发与脏数据校验 (告别硬编码)
		for key in raw_data.keys():
			var val = raw_data[key]
			
			if valid_keys.has(key):
				# 路线 A：如果 Resource 确实声明了这个变量，直接塞进根目录
				entity_data[key] = val
			elif key.begins_with("prop/"):
				# 路线 B：合法的扩展属性，剥离前缀塞进 properties 字典
				var clean_key = key.replace("prop/", "")
				entity_data["properties"][clean_key] = val
			else:
				# 路线 C：幽灵字段！既不在 Resource 里，也没有 prop/ 前缀
				Logging.warn("😨 幽灵列出没！CSV 表头 '%s' 既不是 %s 的原生属性，也没有 'prop/' 前缀。(文件: %s)" % [key, model_class, file_path])
				# 仁慈的架构师给你的兜底：虽然报错，但我还是放进 properties 里，免得你业务读不到数据崩溃
				entity_data["properties"][key] = val
		
		result.append(model_class.new(entity_data))
	
	Logging.info('load %s model %s from %s' % [result.size(), model_class, file_path])
	return result
