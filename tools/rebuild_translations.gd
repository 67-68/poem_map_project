@tool
## 从 CSV 翻译源重新生成 OptimizedTranslation 资源文件。
## 用法: godot --headless --script tools/rebuild_translations.gd
extends SceneTree

func _init() -> void:
	var csv_path = "res://data/1_core_rules/translations/_dynamic_events.csv"
	var out_path = "res://data/1_core_rules/translations/dynamic_events.zh.translation"
	
	print("=== Rebuilding translations ===")
	print("CSV source: ", csv_path)
	print("Output: ", out_path)
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		print("ERROR: Cannot open CSV: ", csv_path)
		quit(1)
		return
	
	# Parse CSV
	var header = file.get_csv_line()
	print("Header: ", header)
	
	var trans = Translation.new()
	trans.locale = "zh"
	
	var line_num = 1
	while not file.eof_reached():
		var line = file.get_csv_line()
		line_num += 1
		if line.is_empty() or line[0].is_empty() or line[0].begins_with("#"):
			continue
		if line.size() < 2:
			print("WARNING: line ", line_num, " has insufficient columns: ", line)
			continue
		var key = line[0].strip_edges()
		var value = line[1].strip_edges()
		if key.is_empty():
			continue
		trans.add_message(key, value)
		print("  [", line_num, "] ", key, " -> ", value)
	
	file.close()
	
	# Save as .translation resource
	var err = ResourceSaver.save(trans, out_path)
	if err != OK:
		print("ERROR: Failed to save translation: ", err)
		quit(1)
		return
	
	print("=== Translation saved successfully to ", out_path, " ===")
	print("Total keys: ", trans.get_message_list().size())
	quit(0)
