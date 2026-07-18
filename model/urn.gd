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
	NORMAL_POEM_EVENT,  # normal_poem_events — 普通诗词事件
	CITY,               # cities（内部合并用）
	EVENT_OPTION,       # event_options — 事件选项（.tres 资源）
	STATE_TRANSISTOR,   # state_transistors — 状态转移器（.tres 资源）
}

static func urn_type_to_str(type: int) -> String:
	""tr("CODE_URN_24DA95FEFE")""
	var names = URN_TYPE.keys()
	if type >= 0 and type < names.size():
		return names[type].to_lower().replace("_", "-")
	Logging.err("Invalid URN type enum value: " + str(type))
	return "unknown"

static func make_urn(type: int, resource_id: String) -> String:
	""tr("CODE_URN_759765FF8C")""
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
	""tr("CODE_URN_34D8031DE2")""
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
# 编辑器模式：通过 SourceOfTruth 配置的 data_dir 使用 DirAccess 扫描目录
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
		# 编辑器模式：通过 DirAccess 扫描 data_dir 目录，按 uuid 匹配
		var data_dir: String = config["data_dir"]
		if data_dir.is_empty():
			Logging.err("get_resource_through_urn: URN type '%s' 没有配置 data_dir, 无法在编辑器模式加载" % normalized_type)
			return null
		return _find_resource_in_dir(data_dir, resource_id)


static func _find_resource_in_dir(data_dir: String, resource_id: String):
	""tr("CODE_URN_0C13829F5F")""
	var dir = DirAccess.open(data_dir)
	if not dir:
		Logging.err("_find_resource_in_dir: 无法打开目录: " + data_dir)
		return null
	
	if dir.list_dir_begin() != OK:
		Logging.err("_find_resource_in_dir: list_dir_begin 失败: " + data_dir)
		return null
	
	var file_name = dir.get_next()
	while file_name != "":
		if file_name in [".", "..", ".DS_Store"]:
			file_name = dir.get_next()
			continue
		if not (file_name.ends_with(".tres") or file_name.ends_with(".tscn")):
			file_name = dir.get_next()
			continue
		
		var file_path = data_dir.path_join(file_name)
		var resource = load(file_path)
		if resource and resource.get("uuid") == resource_id:
			dir.list_dir_end()
			Logging.info("_find_resource_in_dir: 在 %s 中找到 uuid=%s 的资源: %s" % [data_dir, resource_id, file_path])
			return resource
		file_name = dir.get_next()
	
	dir.list_dir_end()
	Logging.err("_find_resource_in_dir: 在 %s 中未找到 uuid=%s 的资源" % [data_dir, resource_id])
	return null
