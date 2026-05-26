extends Node

# 独立的Resources Registry创建逻辑
# 这个文件可以被EditorScript和@tool脚本复用

const RESOURCE_REGISTRY_PATH = "res://core/model/resources.gd"
const DATA_FOLDER = "res://data/"

# 配置选项
var overwrite_existing = true  # 是否覆盖已存在的registry文件
var skip_files_without_uuid = true  # 是否跳过没有uuid或id字段的文件

# 主入口：创建所有resources registry文件
func create_all_registries() -> void:
	print("开始创建resources registry文件...")
	print("跳过无UUID文件: ", skip_files_without_uuid)
	print("覆盖已存在文件: ", overwrite_existing)
	print("")
	
	# 加载ResourceRegistry类
	var resource_registry_script = load(RESOURCE_REGISTRY_PATH)
	if not resource_registry_script:
		print("错误：无法加载ResourceRegistry类")
		return
	
	# 获取所有data文件夹
	var data_folders = get_data_folders()
	print("找到 ", data_folders.size(), " 个data文件夹")
	
	for folder_name in data_folders:
		create_registry_for_folder(folder_name, resource_registry_script)
	
	print("\n所有resources registry文件创建完成！")

# 获取所有data文件夹
func get_data_folders() -> Array:
	var folders = []
	var dir = DirAccess.open(DATA_FOLDER)
	if not dir:
		print("错误：无法打开data文件夹")
		return folders
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			folders.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return folders

# 为指定文件夹创建registry文件
func create_registry_for_folder(folder_name: String, resource_registry_script) -> void:
	print("处理文件夹: ", folder_name)
	
	# 检查registry文件是否已存在
	var registry_path = DATA_FOLDER + folder_name + "_registry.tres"
	if FileAccess.file_exists(registry_path) and not overwrite_existing:
		print("  跳过：registry文件已存在 (设置overwrite_existing=true来覆盖)")
		return
	
	# 创建ResourceRegistry实例
	var registry = resource_registry_script.new()
	registry.registry_version = "1.0.0"
	registry.resources.clear()
	
	# 扫描文件夹中的所有tres文件
	var folder_path = DATA_FOLDER + folder_name + "/"
	var dir = DirAccess.open(folder_path)
	if not dir:
		print("  错误：无法打开文件夹 ", folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var resource_count = 0
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = folder_path + file_name
			var key = extract_key_from_tres(file_path)
			if key:
				# 使用key作为key，文件路径作为value
				registry.resources[key] = file_path
				resource_count += 1
				print("    添加资源: ", key, " -> ", file_path)
			else:
				print("    警告：无法从 ", file_name, " 提取key")
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if resource_count == 0:
		print("  警告：没有找到任何资源文件")
		return
	
	# 保存registry文件
	var result = ResourceSaver.save(registry, registry_path)
	if result == OK:
		print("  ✓ 创建registry文件: ", registry_path, " (包含 ", resource_count, " 个资源)")
	else:
		print("  ✗ 错误：无法保存registry文件 ", registry_path)

# 从tres文件中提取key（uuid或id）
func extract_key_from_tres(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("错误：无法打开文件 ", file_path)
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	# 首先查找自定义uuid字段
	var uuid_regex = RegEx.new()
	uuid_regex.compile(r"uuid\s*=\s*\"([^\"]+)\"")
	var uuid_result = uuid_regex.search(content)
	if uuid_result:
		return uuid_result.get_string(1)
	
	# 如果没有uuid字段，尝试查找id字段
	var id_regex = RegEx.new()
	id_regex.compile(r"id\s*=\s*\"([^\"]+)\"")
	var id_result = id_regex.search(content)
	if id_result:
		print("    使用id字段作为key: ", id_result.get_string(1))
		return id_result.get_string(1)
	
	# 如果都没有找到
	if skip_files_without_uuid:
		print("    跳过：没有找到uuid或id字段")
		return ""
	else:
		# 使用文件名作为key
		var file_name = file_path.get_file().get_basename()
		print("    使用文件名作为key: ", file_name)
		return file_name
