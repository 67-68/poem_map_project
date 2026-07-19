@tool
## 从 CSV 翻译源重新生成 _dynamic_events.{locale}.translation 资源文件（zh, en, ja）。
## 用法: godot --headless -s tools/rebuild_translations.gd
extends SceneTree

func _init() -> void:
	var csv_path := "res://data/1_core_rules/translations/_dynamic_events.csv"
	print("=== Rebuilding translations ===")
	print("CSV source: ", csv_path)

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		print("ERROR: Cannot open CSV: ", csv_path)
		quit(1)
		return

	var header := file.get_csv_line()
	print("Header: ", header)
	# header[0]=key, header[1]=zh, header[2]=en, header[3]=ja
	var col_zh := 1
	var col_en := 2 if header.size() > 2 else -1
	var col_ja := 3 if header.size() > 3 else -1

	var rows: Array[Dictionary] = []
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or line[0].is_empty() or line[0].begins_with("#"):
			continue
		if line.size() < 2:
			continue
		var key := line[0].strip_edges()
		if key.is_empty():
			continue
		var row := {
			"key": key,
			"zh": line[col_zh].strip_edges() if col_zh < line.size() else "",
			"en": line[col_en].strip_edges() if col_en >= 0 and col_en < line.size() else "",
			"ja": line[col_ja].strip_edges() if col_ja >= 0 and col_ja < line.size() else "",
		}
		rows.append(row)
	file.close()

	# ── 为每种有效 locale 生成 .translation ──
	var locales := [
		{"locale": "zh", "col": "zh"},
		{"locale": "en", "col": "en"},
		{"locale": "ja", "col": "ja"},
	]
	var total_generated := 0

	for loc in locales:
		var trans := Translation.new()
		trans.locale = loc["locale"]
		var count := 0
		for row in rows:
			var val: String = row[loc["col"]]
			if val.is_empty():
				continue
			trans.add_message(row["key"], val)
			count += 1
		if count == 0:
			print("WARNING: locale '%s' has 0 entries, skipping" % loc["locale"])
			continue

		var out_path := "res://data/1_core_rules/translations/_dynamic_events.%s.translation" % loc["locale"]
		var err := ResourceSaver.save(trans, out_path)
		if err != OK:
			print("ERROR: Failed to save '%s': %d" % [out_path, err])
			quit(1)
			return
		print("  ✅ %s: %d keys saved to %s" % [loc["locale"], count, out_path])
		total_generated += 1

	print("=== Translation rebuild complete: %d locale(s) generated ===" % total_generated)
	quit(0)
