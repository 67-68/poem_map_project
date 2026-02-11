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

# 【新增】CSV 加载逻辑：将每一行转化为 Dictionary 喂给模型
static func load_csv_model(model_class: Variant, file_path: String) -> Array[GameEntity]:
	file_path = _fix_path(file_path, "csv", Global.PERMANENT_DATA_PATH)
	
	if not FileAccess.file_exists(file_path):
		printerr("😨 CSV 档案人间蒸发！路径：", file_path)
		return []
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var result: Array[GameEntity] = []
	
	# 1. 读取表头 (Headers)
	# 假设第一行是 key 名，比如: id, name, properties/map_index_color
	var headers = file.get_csv_line()
	if headers.size() == 0:
		printerr("💀 你的 CSV 怎么是空的？哪怕只有一行表头呢？")
		return []

	# 2. 逐行扫描
	var line_idx = 1
	while !file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < headers.size(): continue # 跳过空行或残缺行
		line_idx += 1
		
		# 3. 核心：将行数组拼装成构造函数需要的 Dictionary
		var data_dict = {}
		var properties_dict = {}
		
		for i in range(headers.size()):
			var key = headers[i].strip_edges()
			var val = line[i].strip_edges()
			
			# 逻辑分流：如果列名带 '/' 或者属于 properties，自动归类
			if key.begins_with("prop/"):
				properties_dict[key.replace("prop/", "")] = val
			elif key == "id" or key == "uuid" or key == "name" or key == "description":
				data_dict[key] = val
			else:
				# 默认放进 properties，符合你 GameEntity 的反序列化逻辑
				properties_dict[key] = val
		
		data_dict["properties"] = properties_dict
		
		# 4. 实例化
		var entity = model_class.new(data_dict)
		result.append(entity)
		
	Logging.info("✅ 已从 CSV 征调 %d 个领土实体进入内存。" % result.size())
	return result
