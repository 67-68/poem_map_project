@tool
extends Node

# 🚨 废弃 (DEPRECATED) — 2026-06-13
# Registry 系统已全局切除，不再使用。
# 所有资源查找已迁移至：
#   编辑器模式 → URN._find_resource_in_dir() 通过 DirAccess 扫描 data_dir
#   运行时模式 → Database 各字典（通过 DataScanner 填充）
# 保留此文件仅作参考，不执行任何逻辑。

const RESOURCE_REGISTRY_PATH = "res://core/model/resources.gd"
const DATA_FOLDER = "res://data/"

# 配置选项
var overwrite_existing = true  # 是否覆盖已存在的registry文件
var skip_files_without_uuid = true  # 是否跳过没有uuid或id字段的文件
var verbose: bool = true  # 是否输出详细日志（批量同步时静默可减少刷屏）

# 主入口：创建所有resources registry文件
func create_all_registries() -> void:
	if verbose:
		Logging.info("开始创建resources registry文件...")
		Logging.info("跳过无UUID文件:  %s" % [skip_files_without_uuid])
		Logging.info("覆盖已存在文件:  %s" % [overwrite_existing])
		Logging.info("")

	# 加载ResourceRegistry类
	var resource_registry_script = load(RESOURCE_REGISTRY_PATH)
	if not resource_registry_script:
		Logging.info("错误：无法加载ResourceRegistry类")
		return
	
	# 获取所有data文件夹
	var data_folders = get_data_folders()
	if verbose:
		Logging.info("找到  %s 个data文件夹:  %s" % [data_folders.size(), data_folders])
	
	for folder_name in data_folders:
		create_registry_for_folder(folder_name, resource_registry_script)
	
	if verbose:
		Logging.info("\n所有resources registry文件创建完成！")

# 获取所有data文件夹
func get_data_folders() -> Array:
	var folders = []
	var dir = DirAccess.open(DATA_FOLDER)
	if not dir:
		Logging.info("错误：无法打开data文件夹")
		return folders
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			# 🚨 macOS 上 .DS_Store 可能被当成目录，过滤掉
			if file_name not in [".", "..", ".DS_Store"]:
				folders.append(file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return folders

# 为指定文件夹创建registry文件
func create_registry_for_folder(folder_name: String, resource_registry_script) -> void:
	if verbose:
		Logging.info("处理文件夹:  %s" % [folder_name])
	
	# 检查registry文件是否已存在
	var registry_path = DATA_FOLDER + folder_name + "_registry.tres"
	if FileAccess.file_exists(registry_path) and not overwrite_existing:
		if verbose:
			Logging.info("  跳过：registry文件已存在 (设置overwrite_existing=true来覆盖)")
		return
	
	# 创建ResourceRegistry实例
	var registry = resource_registry_script.new()
	registry.registry_version = "1.0.0"
	registry.resources.clear()
	
	# 扫描文件夹中的所有tres文件
	var folder_path = DATA_FOLDER + folder_name + "/"
	var dir = DirAccess.open(folder_path)
	if not dir:
		Logging.info("  错误：无法打开文件夹  %s" % [folder_path])
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var resource_count = 0
	var all_files := []  # 🚨 记录文件夹内所有文件用于诊断
	
	while file_name != "":
		all_files.append(file_name)
		if file_name.ends_with(".tres"):
			var file_path = folder_path + file_name
			# 🚨 验证文件确实存在再处理
			if not FileAccess.file_exists(file_path):
				Logging.info("    警告：DirAccess 列出了文件但 FileAccess.file_exists 返回 false:  %s" % [file_path])
				file_name = dir.get_next()
				continue
			
			var key = extract_key_from_tres(file_path)
			if key:
				registry.resources[key] = file_path
				resource_count += 1
				if verbose:
					Logging.info("    添加资源:  %s ->  %s" % [key, file_path])
			else:
				Logging.info("    警告：无法从  %s 提取key" % [file_name])
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if verbose:
		Logging.info("  文件夹内容 ( %s 项):  %s" % [all_files.size(), all_files])
	
	if resource_count == 0:
		Logging.info("  警告：没有找到任何资源文件 (folder= %s)" % [folder_name])
		# 🚨 诊断：尝试直接 load 确认文件是否可达
		_diagnose_folder(folder_path)
		return
	
	# 保存registry文件
	var result = ResourceSaver.save(registry, registry_path)
	if result == OK:
		if verbose:
			Logging.info("  ✓ 创建registry文件:  %s (包含  %s 个资源)" % [registry_path, resource_count])
	else:
		Logging.info("  ✗ 错误：无法保存registry文件  %s" % [registry_path])

# 🚨 诊断辅助：当 DirAccess 找不到文件时，尝试直接 load 已知路径
func _diagnose_folder(folder_path: String) -> void:
	Logging.info("  诊断：尝试直接探测文件夹  %s" % [folder_path])
	var dir = DirAccess.open(folder_path)
	if not dir:
		Logging.info("  诊断：DirAccess.open 失败")
		return
	
	dir.list_dir_begin()
	var count = 0
	var fname = dir.get_next()
	while fname != "":
		count += 1
		if fname.ends_with(".tres"):
			var fp = folder_path + fname
			if ResourceLoader.exists(fp):
				Logging.info("    诊断: 文件存在且 ResourceLoader.exists=true:  %s" % [fname])
				var res = load(fp)
				if res and "uuid" in res:
					Logging.info("    诊断: load() 成功, uuid= %s" % [res.get("uuid")])
			else:
				Logging.info("    诊断: ResourceLoader.exists=false:  %s" % [fname])
		fname = dir.get_next()
	dir.list_dir_end()
	Logging.info("  诊断: 共列出  %s 项" % [count])

# 从资源文件中提取 key（uuid 或 id）
# 优先级：
#   1. ✅ 直接 load() 资源，访问 uuid 属性（精确可靠，不会被 SubResource 截胡）
#   2. ⬇️ 加载失败 → 退回到文本解析（仅搜索 [resource] 段落）
#   3. ⬇️ 文本也找不到 → 文件名兜底
func extract_key_from_tres(file_path: String) -> String:
	# ── 方案一：直接加载 Resource，访问 uuid/id 属性 ──
	# 🚨 这是唯一不会被 SubResource 中 option uuid 干扰的方式
	var resource = load(file_path)
	if resource:
		if "uuid" in resource:
			var uuid_val = resource.get("uuid")
			if uuid_val is String and not uuid_val.is_empty():
				return uuid_val
		if "id" in resource:
			var id_val = resource.get("id")
			if id_val is String and not id_val.is_empty():
				if verbose:
					Logging.info("    使用id字段作为key:  %s" % [id_val])
				return id_val
	
	# ── 方案二：资源加载失败 / 无 uuid 属性 → 文本解析兜底 ──
	# 只搜索 [resource] 段落，跳过 [sub_resource] 避免被 option uuid 截胡
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		Logging.info("错误：无法打开文件  %s" % [file_path])
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	# 定位到 [resource] 段落 - 使用更灵活的匹配方式
	var resource_marker = "\n[resource]\n"
	var resource_section_start = content.find(resource_marker)
	
	# 🚨 保险：如果 \n[resource]\n 没找到，试试行首的 [resource]
	if resource_section_start == -1:
		resource_marker = "[resource]\n"
		resource_section_start = content.find(resource_marker)
	
	var search_target = content
	if resource_section_start != -1:
		search_target = content.substr(resource_section_start)
	
	var uuid_regex = RegEx.new()
	uuid_regex.compile(r"uuid\s*=\s*\"([^\"]+)\"")
	var uuid_result = uuid_regex.search(search_target)
	if uuid_result:
		return uuid_result.get_string(1)
	
	var id_regex = RegEx.new()
	id_regex.compile(r"id\s*=\s*\"([^\"]+)\"")
	var id_result = id_regex.search(search_target)
	if id_result:
		if verbose:
			Logging.info("    使用id字段作为key:  %s" % [id_result.get_string(1)])
		return id_result.get_string(1)
	
	# ── 方案三：纯兜底 ──
	if skip_files_without_uuid:
		if verbose:
			Logging.info("    跳过：没有找到uuid或id字段")
		return ""
	else:
		var file_name = file_path.get_file().get_basename()
		if verbose:
			Logging.info("    使用文件名作为key:  %s" % [file_name])
		return file_name
