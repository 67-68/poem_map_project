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
const SafeLogger = preload("res://parser/safe_logger.gd")
const ResourceRegistry = preload("res://core/model/resources.gd")
const BaseEvent = preload("res://model/event.gd")
const EventOption = preload("res://model/event/event_option.gd")
const ChoiceResult = preload("res://model/choice_result.gd")
const BaseOperator = preload("res://core/model/base_operator.gd")

# ─── 已知事件注册表路径 ───
# 从 SourceOfTruth.urn_resource_config 提取事件相关的 registry
# 排除非事件的 registry（如 flag/trait/property/action 等）
const EVENT_REGISTRY_PATHS: Array[String] = [
	"res://data/tres_decided_events_registry.tres",
	"res://data/tres_random_event_bai_ye_registry.tres",
	"res://data/tres_random_event_deng_gao_registry.tres",
	"res://data/tres_random_event_du_zhuo_registry.tres",
	"res://data/tres_random_event_fang_shi_registry.tres",
	"res://data/tres_random_event_feng_zhao_registry.tres",
	"res://data/tres_random_event_jiao_you_registry.tres",
	"res://data/tres_random_event_registry.tres",
	"res://data/tres_random_event_special_registry.tres",
	"res://data/tres_history_event_registry.tres",
	"res://data/tres_normal_poem_events_registry.tres",
	"res://data/tres_end_random_events_registry.tres",
]

# 缓存已加载的 registry（避免重复 I/O）
static var _registry_cache: Dictionary = {}  # registry_path -> Dictionary<event_key, resource_path>


# ═══════════════════════════════════════════════════════
# 公开接口
# ═══════════════════════════════════════════════════════

# 根据 event_key 在所有注册表中查找事件 .tres 路径
# 返回 String（res:// 路径）或空字符串
static func find_event_path(event_key: String) -> String:
	if event_key.is_empty():
		SafeLogger.err("[ChainTresEditor] find_event_path: event_key 为空")
		return ""

	# 遍历所有注册表
	for registry_path in EVENT_REGISTRY_PATHS:
		var registry = _load_registry(registry_path)
		if registry == null:
			continue
		if registry.has(event_key):
			var path = registry[event_key]
			SafeLogger.info("[ChainTresEditor] 找到事件 '%s' 在 %s -> %s" % [event_key, registry_path, path])
			return path

	SafeLogger.err("[ChainTresEditor] 未在任何注册表中找到事件 '%s'" % event_key)
	return ""


# 加载事件 .tres 文件
# 返回 BaseEvent 或 null
static func load_event(event_key: String) -> BaseEvent:
	var path = find_event_path(event_key)
	if path.is_empty():
		SafeLogger.err("[ChainTresEditor] load_event: 无法找到事件 '%s' 的路径" % event_key)
		return null

	var resource = load(path)
	if resource == null:
		SafeLogger.err("[ChainTresEditor] load_event: 加载失败: %s (key=%s)" % [path, event_key])
		return null

	if not resource is BaseEvent:
		SafeLogger.err("[ChainTresEditor] load_event: %s 不是 BaseEvent (key=%s, type=%s)" % [path, event_key, typeof(resource)])
		return null

	SafeLogger.info("[ChainTresEditor] 成功加载事件 '%s': %s" % [event_key, path])
	return resource as BaseEvent


# 在事件中查找指定选项
# opt_id 可以是：
#   - UUID（字符串）：匹配 option.uuid
#   - 数字索引（如 "0", "1"）：按 options 数组索引查找
# 返回 EventOption 或 null
static func find_option(event: BaseEvent, opt_id: String) -> EventOption:
	if event == null:
		SafeLogger.err("[ChainTresEditor] find_option: event 为 null")
		return null
	if opt_id.is_empty():
		SafeLogger.err("[ChainTresEditor] find_option: opt_id 为空")
		return null

	# 尝试按 UUID 匹配
	for option in event.options:
		if option == null:
			continue
		if option.uuid == opt_id:
			SafeLogger.info("[ChainTresEditor] 找到选项 (UUID='%s') 在事件 '%s'" % [opt_id, event.uuid])
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
			SafeLogger.info("[ChainTresEditor] 找到选项 (index=%d) 在事件 '%s': '%s'" % [index, event.uuid, option.uuid if not option.uuid.is_empty() else "(无UUID)"])
			return option as EventOption

	SafeLogger.err("[ChainTresEditor] 在事件 '%s' 中未找到选项 '%s' (事件有 %d 个选项)" % [event.uuid, opt_id, event.options.size()])
	return null


# 向选项的 choice_result.operators 追加 Operator
# 如果选项没有 choice_result，自动创建
static func inject_operator(option: EventOption, operator: BaseOperator) -> bool:
	if option == null:
		SafeLogger.err("[ChainTresEditor] inject_operator: option 为 null")
		return false
	if operator == null:
		SafeLogger.err("[ChainTresEditor] inject_operator: operator 为 null")
		return false

	# 确保 choice_result 存在
	if option.choice_result == null:
		option.choice_result = ChoiceResult.new()
		SafeLogger.info("[ChainTresEditor] 为选项 '%s' 创建新的 ChoiceResult" % option.uuid)

	# 追加 operator
	option.choice_result.operators.append(operator)
	SafeLogger.info("[ChainTresEditor] 已注入 %s 到选项 '%s' (%s)" % [operator.get_class(), option.uuid, option.description])
	return true


# 设置选项的 requirement
# 如果已有 requirement，在日志中警告（覆盖）
static func set_requirement(option: EventOption, requirement) -> bool:
	if option == null:
		SafeLogger.err("[ChainTresEditor] set_requirement: option 为 null")
		return false
	if requirement == null:
		SafeLogger.err("[ChainTresEditor] set_requirement: requirement 为 null")
		return false

	if option.requirement != null:
		SafeLogger.warn("[ChainTresEditor] 选项 '%s' 已有 requirement，将被覆盖" % option.uuid)

	option.requirement = requirement
	SafeLogger.info("[ChainTresEditor] 已设置 requirement 到选项 '%s'" % option.uuid)
	return true


# 保存事件 .tres 文件
# 返回 true 表示成功
static func save_event(event: BaseEvent, event_key: String) -> bool:
	if event == null:
		SafeLogger.err("[ChainTresEditor] save_event: event 为 null")
		return false

	var path = find_event_path(event_key)
	if path.is_empty():
		SafeLogger.err("[ChainTresEditor] save_event: 无法找到事件 '%s' 的路径" % event_key)
		return false

	var result = ResourceSaver.save(event, path)
	if result != OK:
		SafeLogger.err("[ChainTresEditor] 保存失败: %s (code=%d)" % [path, result])
		return false

	SafeLogger.info("[ChainTresEditor] 成功保存事件 '%s' -> %s" % [event_key, path])
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

# 加载注册表，返回 { event_key -> resource_path } 字典
static func _load_registry(registry_path: String) -> Dictionary:
	# 缓存命中
	if _registry_cache.has(registry_path):
		return _registry_cache[registry_path]

	var resource = load(registry_path)
	if resource == null:
		SafeLogger.err("[ChainTresEditor] 加载注册表失败: %s" % registry_path)
		_registry_cache[registry_path] = {}
		return {}

	if not resource is ResourceRegistry:
		SafeLogger.err("[ChainTresEditor] %s 不是 ResourceRegistry" % registry_path)
		_registry_cache[registry_path] = {}
		return {}

	var registry = (resource as ResourceRegistry).resources
	_registry_cache[registry_path] = registry
	SafeLogger.info("[ChainTresEditor] 加载注册表 %s: %d 条记录" % [registry_path, registry.size()])
	return registry


# 清除注册表缓存（用于测试/重载）
static func clear_cache() -> void:
	_registry_cache.clear()
	SafeLogger.info("[ChainTresEditor] 注册表缓存已清除")
