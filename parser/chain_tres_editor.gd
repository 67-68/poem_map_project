@tool
extends RefCounted

# ═══════════════════════════════════════════════════════
# ChainTresEditor — 事件 .tres 文件定位/加载/注入/保存
#
# 职责：
#   1. 通过 event_key 在所有注册表中查找事件 .tres 路径
#   2. 使用 ResourceLoader 加载 .tres 文件
#   3. 通过选项 uuid 定位到具体 EventOption
#   4. 注入/修改选项的 choice_result.operators 和 requirement
#   5. 使用 ResourceSaver 保存修改后的 .tres
#
# 设计原则：
#   - 只用 Godot Resource API（ResourceLoader/ResourceSaver），
#     绝不用文本 regex 操作 .tres 文件（防 corruption 💀）
#   - @tool 模式下可直接运行
#
# ⚠️ --script 模式下 class_name 不可用，全部用 preload 替代
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（替代 class_name） ───
const ResourceRegistry = preload("res://core/model/resources.gd")
const BaseEvent = preload("res://model/event.gd")
const EventOption = preload("res://model/event/event_option.gd")
const ChoiceResult = preload("res://model/choice_result.gd")
const BaseOperator = preload("res://core/model/base_operator.gd")
const Logging = preload("res://core/logger.gd")

# ─── 已知事件数据目录 ───
# 替代旧的 registry 文件系统。
# 首次调用 find_event_path() 时扫描这些目录构建 event_key → path 缓存。
const EVENT_SCAN_DIRS: Array[String] = [
	"res://data/3_actions_pool/events/",
	"res://data/3_actions_pool/decided_events/",
	"res://data/4_eras/events/history_events/",
	"res://data/4_eras/events/end_random_events/",
	"res://data/3_actions_pool/write_poem/",
	"res://data/5_story_arcs/",
]

# 缓存：event_key（文件名去后缀）→ 完整 res:// 路径
static var _event_path_cache: Dictionary = {}
static var _cache_initialized: bool = false


# ═══════════════════════════════════════════════════════
# 公开接口
# ═══════════════════════════════════════════════════════

# 根据 event_key 在所有事件数据目录中查找 .tres 路径
# 返回 String（res:// 路径）或空字符串
static func find_event_path(event_key: String) -> String:
	if event_key.is_empty():
		Logging.err("[ChainTresEditor] find_event_path: event_key 为空")
		return ""
	
	_ensure_cache()
	
	if _event_path_cache.has(event_key):
		var path: String = _event_path_cache[event_key]
		Logging.info("[ChainTresEditor] 找到事件 '%s' -> %s" % [event_key, path])
		return path
	
	Logging.err("[ChainTresEditor] 未在已知事件目录中找到事件 '%s'" % event_key)
	return ""


# 加载事件 .tres 文件
# 返回 BaseEvent 或 null
static func load_event(event_key: String) -> BaseEvent:
	var path = find_event_path(event_key)
	if path.is_empty():
		Logging.err("[ChainTresEditor] load_event: 无法找到事件 '%s' 的路径" % event_key)
		return null

	var resource = load(path)
	if resource == null:
		Logging.err("[ChainTresEditor] load_event: 加载失败: %s (key=%s)" % [path, event_key])
		return null

	if not resource is BaseEvent:
		Logging.err("[ChainTresEditor] load_event: %s 不是 BaseEvent (key=%s, type=%s)" % [path, event_key, typeof(resource)])
		return null

	Logging.info("[ChainTresEditor] 成功加载事件 '%s': %s" % [event_key, path])
	return resource as BaseEvent


# 在事件中查找指定选项
# opt_id 可以是：
#   - UUID（字符串）：匹配 option.uuid
#   - 数字索引（如 "0", "1"）：按 options 数组索引查找
# 返回 EventOption 或 null
static func find_option(event: BaseEvent, opt_id: String) -> EventOption:
	if event == null:
		Logging.err("[ChainTresEditor] find_option: event 为 null")
		return null
	if opt_id.is_empty():
		Logging.err("[ChainTresEditor] find_option: opt_id 为空")
		return null

	# 尝试按 UUID 匹配
	for option in event.options:
		if option == null:
			continue
		if option.uuid == opt_id:
			Logging.info("[ChainTresEditor] 找到选项 (UUID='%s') 在事件 '%s'" % [opt_id, event.uuid])
			return option as EventOption

	# 尝试按索引匹配（支持 "0" / "#0" 格式）
	var index := -1
	if opt_id.is_valid_int():
		index = opt_id.to_int()
	elif opt_id.begins_with("#"):
		var stripped = opt_id.substr(1)
		if stripped.is_valid_int():
			index = stripped.to_int()

	if index >= 0 and index < event.options.size():
		var option = event.options[index]
		if option != null:
			Logging.info("[ChainTresEditor] 找到选项 (index=%d) 在事件 '%s': '%s'" % [index, event.uuid, option.uuid if not option.uuid.is_empty() else "(无UUID)"])
			return option as EventOption

	Logging.err("[ChainTresEditor] 在事件 '%s' 中未找到选项 '%s' (事件有 %d 个选项)" % [event.uuid, opt_id, event.options.size()])
	return null


# 向选项的 choice_result.operators 追加 Operator
# 如果选项没有 choice_result，自动创建
static func inject_operator(option: EventOption, operator: BaseOperator) -> bool:
	if option == null:
		Logging.err("[ChainTresEditor] inject_operator: option 为 null")
		return false
	if operator == null:
		Logging.err("[ChainTresEditor] inject_operator: operator 为 null")
		return false

	# 确保 choice_result 存在
	if option.choice_result == null:
		option.choice_result = ChoiceResult.new()
		Logging.info("[ChainTresEditor] 为选项 '%s' 创建新的 ChoiceResult" % option.uuid)

	# 追加 operator
	option.choice_result.operators.append(operator)
	Logging.info("[ChainTresEditor] 已注入 %s 到选项 '%s' (%s)" % [operator.get_class(), option.uuid, option.description])
	return true


# 设置选项的 requirement
# 如果已有 requirement，在日志中警告（覆盖）
static func set_requirement(option: EventOption, requirement) -> bool:
	if option == null:
		Logging.err("[ChainTresEditor] set_requirement: option 为 null")
		return false
	if requirement == null:
		Logging.err("[ChainTresEditor] set_requirement: requirement 为 null")
		return false

	if option.requirement != null:
		Logging.warn("[ChainTresEditor] 选项 '%s' 已有 requirement，将被覆盖" % option.uuid)

	option.requirement = requirement
	Logging.info("[ChainTresEditor] 已设置 requirement 到选项 '%s'" % option.uuid)
	return true


# 保存事件 .tres 文件
# 返回 true 表示成功
static func save_event(event: BaseEvent, event_key: String) -> bool:
	if event == null:
		Logging.err("[ChainTresEditor] save_event: event 为 null")
		return false

	var path = find_event_path(event_key)
	if path.is_empty():
		Logging.err("[ChainTresEditor] save_event: 无法找到事件 '%s' 的路径" % event_key)
		return false

	var result = ResourceSaver.save(event, path)
	if result != OK:
		Logging.err("[ChainTresEditor] 保存失败: %s (code=%d)" % [path, result])
		return false

	Logging.info("[ChainTresEditor] 成功保存事件 '%s' -> %s" % [event_key, path])
	return true


# ═══════════════════════════════════════════════════════
# 便捷方法：加载 + 查找选项 + 注入 + 保存（一站式）
# ═══════════════════════════════════════════════════════

# 加载事件，查找选项，注入一个 operator，保存
# 返回 true 表示全部成功
static func load_find_inject_save(event_key: String, opt_uuid: String, operator: BaseOperator) -> bool:
	var event = load_event(event_key)
	if event == null:
		return false

	var option = find_option(event, opt_uuid)
	if option == null:
		return false

	if not inject_operator(option, operator):
		return false

	return save_event(event, event_key)


# 加载事件，查找选项，设置 requirement，保存
static func load_find_req_save(event_key: String, opt_uuid: String, requirement) -> bool:
	var event = load_event(event_key)
	if event == null:
		return false

	var option = find_option(event, opt_uuid)
	if option == null:
		return false

	if not set_requirement(option, requirement):
		return false

	return save_event(event, event_key)


# ═══════════════════════════════════════════════════════
# 内部方法
# ═══════════════════════════════════════════════════════

# 构建事件路径缓存：扫描所有 EVENT_SCAN_DIRS，以文件名（去.tres后缀）为 key
static func _ensure_cache() -> void:
	if _cache_initialized:
		return
	_cache_initialized = true
	_event_path_cache.clear()
	
	for dir_path in EVENT_SCAN_DIRS:
		var dir = DirAccess.open(dir_path)
		if not dir:
			Logging.warn("[ChainTresEditor] 无法打开事件目录: " + dir_path)
			continue
		if dir.list_dir_begin() != OK:
			Logging.warn("[ChainTresEditor] list_dir_begin 失败: " + dir_path)
			continue
		
		var file_name = dir.get_next()
		while file_name != "":
			if file_name in [".", "..", ".DS_Store"]:
				file_name = dir.get_next()
				continue
			if not file_name.ends_with(".tres"):
				file_name = dir.get_next()
				continue
			
			var full_path = dir_path.path_join(file_name)
			var key = file_name.trim_suffix(".tres")
			if not _event_path_cache.has(key):
				_event_path_cache[key] = full_path
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	Logging.info("[ChainTresEditor] 事件路径缓存构建完成: %d 条记录" % _event_path_cache.size())


# 清除事件路径缓存（用于测试/重载）
static func clear_cache() -> void:
	_cache_initialized = false
	_event_path_cache.clear()
	Logging.info("[ChainTresEditor] 事件路径缓存已清除")
