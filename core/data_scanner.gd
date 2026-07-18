# ----------------------------------------------------------------
# 全量数据加载器 (DataScanner)
# ----------------------------------------------------------------
# 递归扫描 data/ 目录树，将文件夹层级映射为命名空间，
# 构建两种字典结构：
#   1. pool: 扁平字典 { "ns.uuid": Resource }   —— O(1) 全量查表
#   2. bases: 按完整相对路径分表 { "1_core_rules.traits": { "uuid": Resource } }
#      —— 支持 Database 按语义 key 直接取用
#
# 设计原则：
#   - 第一级：DirAccess 运行时递归扫描（桌面端）
#   - 第二级：预构建 JSON 索引降级（HTML5 端 DirAccess 不可用时）
#   - .tres/.tscn → Godot load() 原生加载
#   - .csv → DataLoader.load_csv_model() 加载，模型类通过目录名映射
#   - 所有 Resource 的 uuid 字段保持不动，只用于构建 full_id
#   - 加载时检测全 ID 冲突，防止运行时静默覆盖 💀
# ----------------------------------------------------------------
class_name DataScanner extends RefCounted

# CSV 模型类预加载
const Territory = preload("res://world/province_resource.gd")

# EventBase 模型类预加载（解析 eb_*.json）
const EventBase = preload("res://core/model/event_base.gd")

# HTML5 降级：预构建文件清单路径
const _FILE_INDEX_PATH := "res://data/_file_index.json"

## CSV 文件→模型类映射表
## key: CSV 文件名（不含扩展名），value: 对应的 class reference
## 这是必要的，因为 CSV 不包含自身类型信息
const CSV_MODEL_MAP: Dictionary = {
	"base_province": Territory,
	"territories": Territory,
}

## 扫描加载结果容器
class LoadResult:
	var pool: Dictionary = {}       # { "ns.uuid": Resource }
	var bases: Dictionary = {}      # { "rel.path": { "uuid": Resource } }
	var duplicates: Array[String] = []  # 检测到的冲突 ID 列表
	var scanned_file_count: int = 0

## 扫描 start_path 下的所有子文件夹和 .tres/.csv 文件
## delim: 命名空间分隔符，建议使用 "."
## 策略：先尝试 DirAccess 递归扫描（桌面端），如返回 0 文件则降级到预构建索引（HTML5 端）
static func scan(
	start_path: String = "res://data",
	delim: String = "."
) -> LoadResult:
	var result = LoadResult.new()

	# 第一级：DirAccess 递归扫描（桌面端正常工作）
	var root_dir = DirAccess.open(start_path)
	if root_dir:
		_scan_dir(root_dir, start_path, "", delim, result, "")
		Logging.info("DataScanner: DirAccess 扫描完成，共扫描 %d 个文件，加载 %d 个条目，检测到 %d 个冲突，%d 个 Base" % [
			result.scanned_file_count, result.pool.size(), result.duplicates.size(), result.bases.size()])
	else:
		Logging.warn("DataScanner: 无法打开根目录: " + start_path)

	# 第二级：比较 DirAccess 结果与预构建索引，索引文件数更多则用索引
	var index_files := Util.get_files_from_index(_FILE_INDEX_PATH)
	if index_files.size() > result.scanned_file_count:
		Logging.warn("DataScanner: DirAccess 扫到 %d 个文件，索引有 %d 个文件，降级到索引" % [result.scanned_file_count, index_files.size()])
		var fallback_result = _scan_from_index(start_path, delim)
		if fallback_result.scanned_file_count > 0:
			result = fallback_result
			Logging.info("DataScanner: 预构建索引扫描完成，共扫描 %d 个文件，加载 %d 个条目，检测到 %d 个冲突，%d 个 Base" % [
				result.scanned_file_count, result.pool.size(), result.duplicates.size(), result.bases.size()])
		else:
			Logging.err("DataScanner: 预构建索引也未找到任何文件！")

	return result


## 从预构建 JSON 索引加载（HTML5 降级路径）
static func _scan_from_index(
	start_path: String,
	delim: String
) -> LoadResult:
	var result = LoadResult.new()

	var files: PackedStringArray = Util.get_files_from_index(_FILE_INDEX_PATH)
	if files.is_empty():
		Logging.warn("DataScanner: 预构建索引为空或不可用")
		return result

	Logging.info("DataScanner: 预构建索引包含 %d 个文件路径" % files.size())

	for rel_path in files:
		if not rel_path is String:
			continue
		var file_path = start_path.path_join(rel_path)

		# 从相对路径重建 namespace 和 base
		var parts: PackedStringArray = rel_path.split("/")
		if parts.size() < 1:
			Logging.err("DataScanner: 无效的索引路径: " + rel_path)
			continue

		var file_name = parts[parts.size() - 1]
		var dir_parts = parts.slice(0, parts.size() - 1)

		# 重建 namespace：目录层级用 delim 拼接
		var current_ns = ""
		if dir_parts.size() > 0:
			current_ns = ".".join(dir_parts) + delim

		# 重建 top_level_base：目录层级用 delim 拼接
		var top_level_base = ""
		if dir_parts.size() > 0:
			top_level_base = ".".join(dir_parts)

		# 根据扩展名分流加载
		if file_name.ends_with(".tres") or file_name.ends_with(".tscn"):
			result.scanned_file_count += 1
			_load_resource(file_path, current_ns, result, top_level_base)
		elif file_name.ends_with(".csv"):
			# ── 完整性检查：CSV 可能被 Godot translation importer 转换成 .translation ──
			if not FileAccess.file_exists(file_path):
				Logging.warn("DataScanner: 索引中的 CSV 文件未打包！可能被 translation importer 转换: " + file_path)
				Logging.warn("  提示：检查 %s.import 是否设为 importer=\"csv_translation\"，需改为 importer=\"keep\"" % file_path)
				continue
			result.scanned_file_count += 1
			_load_csv(file_path, current_ns, result, top_level_base, file_name)
		elif file_name.ends_with(".json") and file_name.begins_with("eb_"):
			# ── eb_*.json：EventBase 配置文件 ──
			result.scanned_file_count += 1
			_load_event_base_json(file_path, current_ns, result, top_level_base)
		else:
			Logging.warn("DataScanner: 索引中跳过未知类型文件: " + rel_path)

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
		Logging.err("DataScanner: list_dir_begin 失败: " + current_dir_path)
		return

	var entry_name = dir.get_next()
	while entry_name != "":
		if entry_name in [".", "..", ".DS_Store"]:
			entry_name = dir.get_next()
			continue

		# ── 跳过 _ 前缀文件/文件夹（DSL 源文件，已有预生成的 .tres）──
		if entry_name.begins_with("_"):
			entry_name = dir.get_next()
			continue

		var full_path = current_dir_path.path_join(entry_name)

		if dir.current_is_dir():
			# ── 递归子文件夹：累积命名空间 ──
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				var child_ns = current_ns + entry_name + delim
				# 🚨 改进：bases key 使用完整相对路径而非仅顶层名
				# 如 "3_actions_pool.baiye" 而非 "3_actions_pool"
				var child_base = top_level_base + delim + entry_name if top_level_base != "" else entry_name
				_scan_dir(sub_dir, full_path, child_ns, delim, result, child_base)
			else:
				Logging.err("DataScanner: 无法打开子文件夹: " + full_path)

		elif entry_name.ends_with(".tres") or entry_name.ends_with(".tscn"):
			# ── .tres/.tscn 资源文件 ──
			result.scanned_file_count += 1
			_load_resource(full_path, current_ns, result, top_level_base)

		elif entry_name.ends_with(".csv"):
			# ── CSV 文件：通过 DataLoader 加载 ──
			result.scanned_file_count += 1
			_load_csv(full_path, current_ns, result, top_level_base, entry_name)

		elif entry_name.ends_with(".json") and entry_name.begins_with("eb_"):
			# ── eb_*.json：EventBase 配置文件 ──
			result.scanned_file_count += 1
			_load_event_base_json(full_path, current_ns, result, top_level_base)

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
		Logging.err("DataScanner: 加载失败: " + file_path)
		return

	# 从资源中提取 uuid
	var uuid = _extract_uuid(resource)
	if uuid.is_empty():
		Logging.warn("DataScanner: 跳过无 uuid 的资源: " + file_path)
		return

	var full_id = current_ns + uuid

	# ── 全局池冲突检测 ──
	if result.pool.has(full_id):
		var msg = tr("CODE_DATA_SCANNER_87B9B14697") % [full_id, file_path]
		Logging.err(msg)
		result.duplicates.append(full_id)
		return

	result.pool[full_id] = resource
	Logging.debug("DataScanner: 加载 [%s] <- %s" % [full_id, file_path])

	# ── 自动填充命名空间 ──
	# 对所有 Resource 写入 _namespace，便于调试追溯来源
	if "_namespace" in resource:
		resource.set("_namespace", current_ns)
		Logging.debug("DataScanner: 写入 _namespace='%s' 到资源 '%s'" % [current_ns, full_id])

	# 🚨 自动速度升级规则：仅当 display_speed 为默认值 FAST(0) 时才升级到 SLOW
	# 仅对 namespace 以 "5_story_arcs." 开头的资源生效
	# ⚡ display_speed 已迁移至 ui_decl 子资源
	if current_ns.begins_with("5_story_arcs."):
		var ui_decl_res = resource.get("ui_decl") if "ui_decl" in resource else null
		if ui_decl_res:
			var cur_speed = ui_decl_res.get("display_speed") if "display_speed" in ui_decl_res else 0
			if cur_speed == 0:  # DisplaySpeed.FAST
				ui_decl_res.set("display_speed", 1)  # DisplaySpeed.SLOW
				Logging.debug("DataScanner: 事件 '%s' 自动标记为 SLOW（namespace: %s）" % [full_id, current_ns])
			else:
				Logging.debug("DataScanner: 事件 '%s' 保持手动设定的 display_speed=%d（namespace: %s）" % [full_id, cur_speed, current_ns])

	# ── 按完整相对路径分表 ──
	# top_level_base 现在是完整相对路径（如 "1_core_rules.traits"、"3_actions_pool.baiye"）
	if top_level_base != "":
		if not result.bases.has(top_level_base):
			result.bases[top_level_base] = {}
		if result.bases[top_level_base].has(uuid):
			Logging.err("DataScanner: Base '%s' 内 uuid 冲突！uuid='%s' 已存在（文件: %s）" % [
				top_level_base, uuid, file_path])
			# 不 return，允许继续（全局池胜出）
		result.bases[top_level_base][uuid] = resource


static func _load_csv(
	file_path: String,
	current_ns: String,
	result: LoadResult,
	top_level_base: String,
	file_name: String
) -> void:
	# 从 CSV 文件名（不含扩展名）查找对应的模型类
	var csv_basename = file_name.get_basename()
	var model_class = CSV_MODEL_MAP.get(csv_basename)
	if model_class == null:
		Logging.warn("DataScanner: CSV 文件 '%s' 未在 CSV_MODEL_MAP 中注册，跳过" % file_name)
		return

	# 调用 DataLoader 加载 CSV
	# DataLoader.load_csv_model 接受 class reference，使用 model_class.new(item)
	var items: Array = DataLoader.load_csv_model(model_class, file_path)
	if items.is_empty():
		Logging.warn("DataScanner: CSV 文件 '%s' 加载结果为空" % file_name)
		return

	# 构建 { uuid: item } 字典
	var csv_dict: Dictionary = {}
	for item in items:
		if "uuid" in item:
			var item_uuid = item.get("uuid")
			if item_uuid is String and not item_uuid.is_empty():
				csv_dict[item_uuid] = item

	if csv_dict.is_empty():
		Logging.warn("DataScanner: CSV 文件 '%s' 没有包含有效 uuid 的项目" % file_name)
		return

	# CSV 的 bases key 使用 "目录路径 + 文件名"
	# 例如 "1_core_rules.base_province"
	var csv_bases_key = top_level_base + "." + csv_basename if top_level_base != "" else csv_basename
	result.bases[csv_bases_key] = csv_dict
	Logging.info("DataScanner: CSV 加载完成 [%s] <- %s（%d 条）" % [csv_bases_key, file_path, csv_dict.size()])

	# ── CSV 数据也写入全局 pool（SSOT：_build_unified_index 只扫 pool）──
	for item_uuid in csv_dict:
		var item = csv_dict[item_uuid]
		var full_id = current_ns + item_uuid
		if result.pool.has(full_id):
			var msg = tr("CODE_DATA_SCANNER_D144DA1A9F") % full_id
			Logging.err(msg)
			result.duplicates.append(full_id)
			continue
		result.pool[full_id] = item
		Logging.debug("DataScanner: CSV 写入 pool [%s] <- %s" % [full_id, file_path])


static func _load_event_base_json(
	file_path: String,
	current_ns: String,
	result: LoadResult,
	top_level_base: String
) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		Logging.err("DataScanner: 无法打开 JSON 文件: " + file_path)
		return

	var raw_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_err = json.parse(raw_text)
	if parse_err != OK:
		Logging.err("DataScanner: JSON 解析失败: %s (错误: %s)" % [file_path, json.get_error_message()])
		return

	var data = json.get_data()
	if not data is Dictionary:
		Logging.err("DataScanner: JSON 根节点不是字典: " + file_path)
		return

	var event_base = EventBase.new()

	# 提取字段（JSON 用 "id"，映射到 uuid）
	event_base.uuid = str(data.get("id", ""))
	event_base.name = str(data.get("name", ""))
	event_base.era = str(data.get("era", ""))
	event_base.draw_strategies = str(data.get("draw_strategies", ""))

	# reset_on_empty: JSON 中是 bool
	if data.has("reset_on_empty"):
		event_base.reset_on_empty = bool(data["reset_on_empty"])

	# events: JSON 数组 → Array[String]
	if data.has("events"):
		var raw_events: Array = data["events"]
		var ev_arr: Array[String] = []
		for ev in raw_events:
			ev_arr.append(str(ev))
		event_base.events = ev_arr

	# generation_configs: 原始 JSON，不解析
	if data.has("generation_configs") and data["generation_configs"] is Dictionary:
		event_base.generation_configs = data["generation_configs"]

	var uuid = event_base.uuid
	if uuid.is_empty():
		Logging.warn("DataScanner: eb_*.json 缺少 'id' 字段: " + file_path)
		return

	var full_id = current_ns + uuid

	# ── 全局池冲突检测 ──
	if result.pool.has(full_id):
		Logging.err("DataScanner: EventBase ID 冲突！full_id='%s' 已存在（文件: %s）" % [full_id, file_path])
		result.duplicates.append(full_id)
		return

	result.pool[full_id] = event_base
	Logging.debug("DataScanner: 加载 EventBase [%s] <- %s (events=%d, strategy=%s)" % [full_id, file_path, event_base.events.size(), event_base.draw_strategies])

	# ── 按完整相对路径分表 ──
	if top_level_base != "":
		if not result.bases.has(top_level_base):
			result.bases[top_level_base] = {}
		result.bases[top_level_base][uuid] = event_base


static func _extract_uuid(resource: Resource) -> String:
	if "uuid" in resource:
		var val = resource.get("uuid")
		if val is String and not val.is_empty():
			return val
	if "id" in resource:
		var val = resource.get("id")
		if val is String and not val.is_empty():
			return val
	return ""
