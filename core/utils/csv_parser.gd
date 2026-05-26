# ====================================================================
# 芯片 1：纯粹的 CSV 解析工具（无状态，随便怎么测都不会死锁）
# ====================================================================
class_name CryptoCSVParser
extends RefCounted


# 将原始 CSV 字符串解析为字典数组
static func parse_string_to_matrix(raw_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines = raw_text.split("\n")
	
	if lines.size() < 2:
		return result
	
	var headers = lines[0].strip_edges().split(",")
	
	for i in range(1, lines.size()):
		var line = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var values = _parse_csv_line(line)
		var row_data = {}
		
		for j in range(headers.size()):
			if j < values.size():
				var key = headers[j].strip_edges()
				var value = values[j].strip_edges()
				# 去除字段值的引号
				if value.begins_with('"') and value.ends_with('"'):
					value = value.substr(1, value.length() - 2)
				row_data[key] = value
		
		if not row_data.is_empty():
			result.append(row_data)
	
	return result


# 解析 CSV 行，处理引号和逗号
static func _parse_csv_line(line: String) -> Array[String]:
	var result: Array[String] = []
	var current = ""
	var in_quotes = false
	
	for i in range(line.length()):
		var ch = line[i]
		if ch == '"':
			in_quotes = not in_quotes
		elif ch == ',' and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += ch
	
	result.append(current)
	return result
