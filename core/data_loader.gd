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

# 这是一个静态函数，意味着你不需要实例化节点就能直接用 DataLoader.load_json(...)
static func load_json_file(core_note_file_path: String, path_point_file_path: String):
	# core 可以装着很多owner, path point也可以装着很多path_point, 只要有owner_id就行
	var core_notes = _load_file(core_note_file_path)
	var path_point_notes:Array = _load_file(path_point_file_path)

	var result = []
	for note in core_notes:
		var correlated_notes = []
		for note_ in path_point_notes:
			if note_.get('properties',{}).get('owner_uuid','') == note.get('uuid'):
				correlated_notes.append(note_)

		result.append(PoetData.new(note,correlated_notes))
		
	# 4. 返回解析好的数据（通常是 Array 或 Dictionary）
	return result