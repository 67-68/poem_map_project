@tool
class_name URN
# ============================================================
# URN System - 统一资源名称标识符
# 格式: urn:<resource-type>:<resource-id>
# 示例: urn:poet:libai_001
#       urn:poem:jiang_jin_jiu
#       urn:action:travel_parting_withLiBai
# ============================================================

enum URN_TYPE {
	POET,               # poet_data — 诗人数据
	POEM,               # poem_data — 诗词数据
	POEM_TASTE,         # poem_taste — 诗歌品味配置
	FACTION,            # factions — 势力
	PROVINCE,           # base_province — 基础省份（CSV）
	TERRITORY,          # territories — 领土（CSV）
	MSGER,              # msger_data — 消息者数据
	HISTORY_EVENT,      # history_events — 历史事件
	RANDOM_EVENT,       # random_events — 随机事件
	END_RANDOM_EVENT,   # end_random_events — 结局随机事件
	CHAT_BUBBLE,        # chat_bubble_data — 聊天气泡
	FOCUSED_CHAT,       # focused_chat_data — 聚焦对话
	AMBITION,           # ambitions — 抱负/雄心
	TRAIT,              # traits — 特性
	PROPERTY,           # properties — 属性
	ACTION,             # actions — 行动
	DECISION,           # decisions — 决策
	DECIDED_EVENT,      # decided_events — 已决定事件
	IMAGINARY,          # imaginaries — 想象物
	TAG,                # tags — 标签
	FLAG,               # flags — 标记
	LIFE_PATH_POINT,    # life_path_points — 人生轨迹点
	LEGENDARY_POEM,     # legendary_poems — 传奇诗词
	NORMAL_POEM_EVENT,  # normal_poem_events — 普通诗词事件
	CITY,               # cities（内部合并用）
	EVENT_OPTION,       # event_options — 事件选项（.tres 资源）
}

static func urn_type_to_str(type: int) -> String:
	"""将 URN_TYPE enum 值转换为 URN 资源类型字符串（小写+连字符）"""
	var names = URN_TYPE.keys()
	if type >= 0 and type < names.size():
		return names[type].to_lower().replace("_", "-")
	Logging.err("Invalid URN type enum value: " + str(type))
	return "unknown"

static func make_urn(type: int, resource_id: String) -> String:
	"""生成完整的 URN 字符串: urn:<type>:<id>"""
	var type_str = urn_type_to_str(type)
	if type_str == "unknown":
		Logging.err("Failed to create URN for type " + str(type) + " with id " + resource_id)
	return "urn:%s:%s" % [type_str, resource_id]

static func parse_urn(urn: String) -> Dictionary:
	"""解析 URN 字符串，返回 { type, resource_id }
	若解析失败返回空字典并打错误日志
	"""
	var parts = urn.split(":")
	if parts.size() != 3:
		Logging.err("Invalid URN format: " + urn + " — expected 'urn:<type>:<id>'")
		return {}
	if parts[0] != "urn":
		Logging.err("Invalid URN prefix: " + urn + " — expected 'urn:...'")
		return {}
	return {
		"type": parts[1],
		"resource_id": parts[2]
	}

static func find_urn_type(type_str: String) -> int:
	"""通过字符串查找对应的 URN_TYPE enum 值，未找到返回 -1"""
	var normalized = type_str.to_lower().replace("-", "_")
	var names = URN_TYPE.keys()
	for i in range(names.size()):
		if names[i].to_lower() == normalized:
			return i
	Logging.err("Unknown URN type string: " + type_str)
	return -1


# ============================================================
# URN Resource Lookup
# ============================================================
# 通过 URN 字符串查找对应的 .tres 资源
# 非编辑器模式：通过 Database singleton 在已加载的字典中查找
# 编辑器模式：通过 SourceOfTruth 配置加载 registry 文件并查找
# ============================================================
static func get_resource_through_urn(urn_string: String):
	"""通过 URN 获取对应的 Resource（仅 .tres 类型）
	
	格式: urn:<type>:<resource_id>
	示例: urn:poet:libai_001
	"""
	var parsed = parse_urn(urn_string)
	if parsed.is_empty():
		Logging.err("get_resource_through_urn: 无法解析 URN: " + urn_string)
		return null
	
	var type_str = parsed["type"]
	var resource_id = parsed["resource_id"]
	
	# 🚨 不经过 find_urn_type() 转 int，直接用 normalized 字符串 key 查配置表。
	# @tool 模式下 enum 跨脚本解析异常，int key 查找可能失败 💀
	var normalized_type = type_str.to_lower().replace("-", "_")
	
	var config = SourceOfTruth.urn_resource_config.get(normalized_type)
	if config == null:
		Logging.err("get_resource_through_urn: URN type '%s' (normalized: '%s') 未在配置表中找到" % [type_str, normalized_type])
		return null
	
	if not Engine.is_editor_hint():
		# 非编辑器模式：直接从 Database 的字典中查找
		var db_field: String = config["db_field"]
		var dict: Dictionary = Database.get(db_field)
		if dict == null:
			Logging.err("get_resource_through_urn: Database 中没有字段: " + db_field)
			return null
		var resource = dict.get(resource_id)
		if resource == null:
			Logging.err("get_resource_through_urn: 在 Database.%s 中未找到 resource_id: %s" % [db_field, resource_id])
			return null
		return resource
	else:
		# 编辑器模式：通过 registry 文件查找
		var registry_path: String = config["registry"]
		var registry = load(registry_path)
		if registry == null or registry.resources == null:
			Logging.err("get_resource_through_urn: 无法加载 registry: " + registry_path)
			return null
		
		# 第一步：尝试直接用 resource_id 作为 key 在 registry 中查找
		if registry.resources.has(resource_id):
			var resource = load(registry.resources[resource_id])
			if resource:
				return resource
			Logging.err("get_resource_through_urn: registry 中有 key 但文件加载失败: " + registry.resources[resource_id])
			return null
		
		# 第二步：key 匹配失败，加载所有资源并尝试按 uuid 匹配
		Logging.warn("get_resource_through_urn: registry 中未找到 key '%s'，尝试按 uuid 遍历匹配..." % resource_id)
		for key in registry.resources:
			var file_path = registry.resources[key]
			var resource = load(file_path)
			if resource == null:
				continue
			if resource.get("uuid") == resource_id:
				Logging.info("get_resource_through_urn: 通过 uuid 匹配成功: %s -> %s" % [resource_id, file_path])
				return resource
		
		Logging.err("get_resource_through_urn: 在 registry %s 中未找到 resource_id/uuid = %s 的资源" % [registry_path, resource_id])
		return null
