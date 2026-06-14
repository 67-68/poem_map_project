# ====================================================================
# 芯片 2：资源导出工具（将 Resource 数组导出为 .tres 文件）
# ====================================================================
class_name ResourceAssetExporter
extends RefCounted


# 将资源数组导出到指定文件夹
const Logging = preload("res://core/logger.gd")
static func export_to_tres_folder(resources: Array[Resource], folder_path: String) -> void:
	# 确保文件夹路径以 / 结尾
	if not folder_path.ends_with("/"):
		folder_path += "/"
	
	# 确保文件夹存在
	if not DirAccess.dir_exists_absolute(folder_path):
		DirAccess.make_dir_absolute(folder_path)
		Logging.info("[EXPORTER] 创建文件夹: %s" % folder_path)
	
	var saved_count = 0
	var skipped_count = 0
	
	for resource in resources:
		if resource == null:
			Logging.info("[EXPORTER] Warning: 跳过 null 资源")
			skipped_count += 1
			continue
		
		if not _is_resource_savable(resource):
			Logging.info("[EXPORTER] Warning: 跳过无效资源 (类名: %s)" % resource.get_class())
			skipped_count += 1
			continue
		
		var file_path = _generate_resource_file_path(resource, folder_path)
		if file_path.is_empty():
			skipped_count += 1
			continue
		
		var save_result = ResourceSaver.save(resource, file_path)
		if save_result == OK:
			Logging.info("[EXPORTER] 保存资源到文件: %s" % file_path)
			saved_count += 1
		else:
			Logging.err("[EXPORTER] 保存资源失败: %s, 错误代码: %d" % [file_path, save_result])
			skipped_count += 1
	
	Logging.info("[EXPORTER] 导出完成！成功: %d, 跳过: %d 🤓☝️" % [saved_count, skipped_count])


# 检查资源是否可以保存
static func _is_resource_savable(resource: Resource) -> bool:
	if resource == null:
		return false
	
	if not resource is Resource:
		return false
	
	return true


# 为资源生成文件路径
static func _generate_resource_file_path(resource: Resource, folder_path: String) -> String:
	var base_filename = _extract_resource_filename(resource)
	if base_filename.is_empty():
		return ""
	
	var safe_filename = _sanitize_filename(base_filename)
	
	# 检查非法字符
	var invalid_chars_regex = RegEx.new()
	invalid_chars_regex.compile("[^a-zA-Z0-9_]")
	var invalid_chars = invalid_chars_regex.search_all(safe_filename)
	
	if not invalid_chars.is_empty():
		var invalid_chars_str = ""
		for result in invalid_chars:
			invalid_chars_str += result.get_string()
		Logging.err("[EXPORTER] 资源名称包含非法字符: %s, 非法字符: %s, 拒绝保存" % [base_filename, invalid_chars_str])
		return ""
	
	# 确保文件名唯一
	var final_filename = safe_filename
	var index = 0
	while FileAccess.file_exists(folder_path + final_filename + ".tres"):
		index += 1
		final_filename = safe_filename + "_%d" % index
	
	return "%s%s.tres" % [folder_path, final_filename]


# 从资源提取文件名
static func _extract_resource_filename(resource: Resource) -> String:
	var base_filename = ""
	
	# 优先尝试获取 uuid 属性
	if resource.has_method("get") and resource.get("uuid") != null:
		var uuid = resource.get("uuid")
		if uuid is String and not uuid.is_empty():
			base_filename = uuid
			Logging.info("[EXPORTER] 使用 uuid 作为文件名: %s" % base_filename)
	
	# 如果没有 uuid，尝试获取 resource_name
	if base_filename.is_empty() and resource.has_method("get_resource_name"):
		var res_name = resource.get_resource_name()
		if not res_name.is_empty():
			base_filename = res_name
	
	if base_filename.is_empty():
		# 尝试从 resource_path 获取文件名
		var res_path = resource.resource_path
		if not res_path.is_empty():
			base_filename = res_path.get_file().get_basename()
	
	if base_filename.is_empty():
		# 使用资源的类名
		base_filename = resource.get_class()
		if base_filename == "Resource":
			Logging.info("[EXPORTER] Warning: 资源没有有效名称，跳过保存 (类名: %s)" % base_filename)
			return ""
	
	return base_filename


# 清理文件名中的特殊字符
static func _sanitize_filename(filename: String) -> String:
	# 将冒号转化为单下划线，连字符也转化为下划线
	var safe_filename = filename.replace(":", "_").replace("-", "_")
	return safe_filename
