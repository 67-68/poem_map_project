# ----------------------------------------------------------------
# 事件库加载器 (EventBaseLoader)
# ----------------------------------------------------------------
# 递归扫描 data/event_base/ 目录树，将文件夹层级映射为命名空间，
# 构建两种字典结构：
#   1. pool: 扁平事件字典 { "ns.uuid": Resource }   —— O(1) 全量查表
#   2. bases: 按顶层 base 分表 { "actions": { "uuid": Resource } } —— eventbase.event_id 语法支持
#
# 设计原则：
#   - 零中间注册表文件，纯 DirAccess 运行时递归扫描
#   - 事件 .tres 内的 uuid 字段保持不动，只用于构建 full_id
#   - 加载时检测全 ID 冲突，防止运行时静默覆盖 💀
# ----------------------------------------------------------------
class_name EventBaseLoader extends RefCounted

## 扫描加载结果容器
class LoadResult:
	var pool: Dictionary = {}       # { "ns.uuid": Resource }
	var bases: Dictionary = {}      # { "base_name": { "uuid": Resource } }
	var duplicates: Array[String] = []  # 检测到的冲突 ID 列表
	var scanned_file_count: int = 0

## 扫描 start_path 下的所有子文件夹和 .tres 文件
## delim: 命名空间分隔符，建议使用 "."
static func scan(
	start_path: String = "res://data/event_base",
	delim: String = "."
) -> LoadResult:
	var result = LoadResult.new()
	var root_dir = DirAccess.open(start_path)
	if not root_dir:
		push_error("EventBaseLoader: 无法打开根目录: " + start_path)
		return result

	_scan_dir(root_dir, start_path, "", delim, result, "")

	Logging.info("EventBaseLoader: 扫描完成，共扫描 %d 个文件，加载 %d 个事件，检测到 %d 个冲突，%d 个 Base" % [
		result.scanned_file_count, result.pool.size(), result.duplicates.size(), result.bases.size()])
	return result


static func _scan_dir(
	dir: DirAccess,
	current_dir_path: String,
	current_ns: String,
	delim: String,
	result: LoadResult,
	top_level_base: String  # 当前分支所属的顶层 base 名称（根层时为空）
) -> void:
	if dir.list_dir_begin() != OK:
		push_error("EventBaseLoader: list_dir_begin 失败: " + current_dir_path)
		return

	var entry_name = dir.get_next()
	while entry_name != "":
		if entry_name in [".", "..", ".DS_Store"]:
			entry_name = dir.get_next()
			continue

		var full_path = current_dir_path.path_join(entry_name)

		if dir.current_is_dir():
			# ── 递归子文件夹：累积命名空间 ──
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				var child_ns = current_ns + entry_name + delim
				# 顶层文件夹名即 base 名称
				var child_base = top_level_base if top_level_base != "" else entry_name
				_scan_dir(sub_dir, full_path, child_ns, delim, result, child_base)
			else:
				push_error("EventBaseLoader: 无法打开子文件夹: " + full_path)
		elif entry_name.ends_with(".tres") or entry_name.ends_with(".tscn"):
			# ── 发现资源文件：加载 ──
			result.scanned_file_count += 1
			_load_resource(full_path, current_ns, result, top_level_base)

		entry_name = dir.get_next()

	dir.list_dir_end()


static func _load_resource(
	file_path: String,
	current_ns: String,
	result: LoadResult,
	top_level_base: String
) -> void:
	var resource = load(file_path)
	if not resource:
		push_error("EventBaseLoader: 加载失败: " + file_path)
		return

	# 从资源中提取 uuid
	var uuid = _extract_uuid(resource)
	if uuid.is_empty():
		Logging.warn("EventBaseLoader: 跳过无 uuid 的资源: " + file_path)
		return

	var full_id = current_ns + uuid

	# ── 全局池冲突检测 ──
	if result.pool.has(full_id):
		var msg = "EventBaseLoader: ID 冲突！full_id='%s' 已存在（文件: %s）" % [full_id, file_path]
		push_error(msg)
		result.duplicates.append(full_id)
		return

	result.pool[full_id] = resource
	Logging.info("EventBaseLoader: 加载事件 [%s] <- %s" % [full_id, file_path])

	# ── 自动填充命名空间和显示速度 ──
	# current_ns 是纯目录前缀，如 "story_arcs.changan_rainfall."（不包含 uuid）
	# 这使 NarrativeOverlay 可以直接通过 _namespace.begins_with("story_arcs.") 做拦截
	# 仅在资源是 BaseEvent 或其子类时写入（避免污染非事件资源）
	if "_namespace" in resource:
		resource.set("_namespace", current_ns)
		Logging.info("EventBaseLoader: 写入 _namespace='%s' 到事件 '%s'" % [current_ns, full_id])
	if "display_speed" in resource and current_ns.begins_with("story_arcs."):
		resource.set("display_speed", 1)  # DisplaySpeed.SLOW
		Logging.info("EventBaseLoader: 事件 '%s' 自动标记为 SLOW（namespace: %s）" % [full_id, current_ns])

	# ── 按顶层 base 分表 ──
	if top_level_base != "":
		if not result.bases.has(top_level_base):
			result.bases[top_level_base] = {}
		if result.bases[top_level_base].has(uuid):
			push_error("EventBaseLoader: Base '%s' 内 uuid 冲突！uuid='%s' 已存在（文件: %s）" % [
				top_level_base, uuid, file_path])
			# 不 return，允许继续（全局池胜出）
		result.bases[top_level_base][uuid] = resource


static func _extract_uuid(resource: Resource) -> String:
	"""从 Resource 中提取 uuid，支持 'uuid' 和 'id' 字段"""
	if "uuid" in resource:
		var val = resource.get("uuid")
		if val is String and not val.is_empty():
			return val
	if "id" in resource:
		var val = resource.get("id")
		if val is String and not val.is_empty():
			return val
	return ""
