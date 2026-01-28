class_name DataLoader extends RefCounted

static func _load_file(file_path: String):
	# 1. 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		printerr("我的天呐，文件找不到：", file_path)
		return null
	
	# 2. 打开文件并读取文本
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	
	# 3. 解析 JSON
	var json = JSON.new()
	var error = json.parse(content)
	
	if error != OK:
		printerr("JSON 格式写错了兄弟！在第 ", json.get_error_line(), " 行")
		return null
	
	return json.data

static func load_data_model(model_class: Variant ,file_path: String) -> Array[GameEntity]:
	if not file_path.ends_with('json') and not file_path.begins_with('res://'):
		file_path = Global.DATA_PATH + file_path
	var json_content = _load_file(file_path)
	return model_class.new(json_content)