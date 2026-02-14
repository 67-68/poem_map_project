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
static func load_json_model(model_class: Variant, file_path: String) -> Array[GameEntity]:
	file_path = _fix_path(file_path, "json",Global.DATA_PATH)
	
	if not FileAccess.file_exists(file_path):
		printerr("💀 JSON 丢失！文件路径：", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	
	if content == null:
		printerr("😡 JSON 格式错误，请检查语法：", file_path)
		return []
		
	var result: Array[GameEntity] = []
	# 容错处理：如果 JSON 只有单个对象而不是数组，包装成数组
	var items = content if content is Array else [content]
	for item in items:
		result.append(model_class.new(item))
	return result
static func load_csv_model(model_class: Variant, file_path: String) -> Array[GameEntity]:
	file_path = _fix_path(file_path, "csv", Global.PERMANENT_DATA_PATH)
	if not FileAccess.file_exists(file_path):
		printerr("😨 CSV 档案被次元放逐了！路径：", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var result: Array[GameEntity] = []
	var headers = file.get_csv_line()
	
	while !file.eof_reached():
		var line = file.get_csv_line()
		# 架构师提醒：即使 line.size == 1 但 line[0] 为空，也说明这行是废纸
		if line[0].strip_edges() == "" or line[0].begins_with("#") and line.size() == 1:
			continue
		
		var raw_data = {}
		for i in range(headers.size()):
			var key = headers[i].strip_edges()
			var val = line[i].strip_edges()
			
			# 处理数组逻辑: [a;b;c] -> Array
			if val.begins_with("[") and val.ends_with("]"):
				var content = val.substr(1, val.length() - 2)
				val = Array(content.split(";", false)) # false 表示剔除空元素
			
			raw_data[key] = val

		# --- 数据归一化逻辑 (Normalization) ---
		var entity_data = {"properties": {}}
		
		# 1. 坐标聚合：把分家的 x, y 合并成 Vector2
		if raw_data.has("uv_x") and raw_data.has("uv_x"):
			entity_data["uv_position"] = Vector2(float(raw_data.uv_x), float(raw_data.uv_y))
		elif raw_data.has("x") and raw_data.has("y"):
			entity_data["position"] = Vector2(float(raw_data.x), float(raw_data.y))
			Logging.warn('使用正常position加载了数据，请确认数据中的position是符合游戏的')
		
		# 2. 分类归档：哪些进核心字段，哪些进属性字典
		for key in raw_data.keys():
			var clean_key = key.replace("prop/", "")
			if key in ["id", "uuid", "name", "description", "position", "year", "year_num"]:
				entity_data[key] = raw_data[key]
			else:
				entity_data["properties"][clean_key] = raw_data[key]
		
		# 3. 实例化：让构造函数直接吃这份精美的菜单
		result.append(model_class.new(entity_data))
	
	Logging.info("✅ 成功部署 %d 个模型实体。" % result.size())
	return result
