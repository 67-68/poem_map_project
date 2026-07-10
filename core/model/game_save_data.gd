class_name GameSaveData extends RefCounted
## GameSaveData — 运行时所有可持久化状态的唯一真源 (Single Source of Truth)
##
## 此 RefCounted 实例由 GameSave Autoload 持有，所有 Autoload（PlayerState、
## GameState、TimeService、Database）的可变字段均通过 getter/setter 代理到此实例。
## SourceOfTruth 除外（仅用于调试初始值注入）。

# ════════════════════════════════════════════════════════════════
# 属性 (Properties) — 平替 Database.properties[xxx].val
# key: prop_uuid (如 "money", "health"), value: int
# ════════════════════════════════════════════════════════════════
var properties: Dictionary = {}

# ════════════════════════════════════════════════════════════════
# 情绪 (Emotions) — 原 PlayerState.emotions
# key: emo_name (如 "sorrow"), value: int
# ════════════════════════════════════════════════════════════════
var emotions: Dictionary = {}

# ════════════════════════════════════════════════════════════════
# Flag — 原 PlayerState.flags（含 RelationFlagManager 虚拟 flag）
# key: flag_id, value: String/int/bool
# ════════════════════════════════════════════════════════════════
var flags: Dictionary = {}

# ════════════════════════════════════════════════════════════════
# 特质 (Traits) — 原 PlayerState.traits
# Array of trait uuid strings, e.g. ["disease_fenghan", "lilinfu_student"]
# 注意：main_* 主线等级 trait（main_baiye_1 等 20 个）已在 2026-07-10 删除。
# 左侧面板 TraitGrid 有防御性过滤，旧存档残留的 main_* uuid 不会显示。
# ════════════════════════════════════════════════════════════════
var traits: Array[String] = []

# ════════════════════════════════════════════════════════════════
# 身份 / 位置
# ════════════════════════════════════════════════════════════════
var player_name: String = "杜甫"
var current_location: String = "yong_zhou"
var stay_place: String = "xishi"

# ════════════════════════════════════════════════════════════════
# 野心 — 存 UUID 字符串，PlayerState 的 getter 从 Database 实时解析
# ambition_start_days: 野心激活时的累计天数（用于计算剩余旬数），-1=未激活
# ════════════════════════════════════════════════════════════════
var ambition_uuid: String = ""
var ambition_start_days: int = -1

# ════════════════════════════════════════════════════════════════
# 行动状态
# ════════════════════════════════════════════════════════════════
var current_action_tags: Array[String] = []
var last_action_tags: Array[String] = []

# ════════════════════════════════════════════════════════════════
# 诗词 — 原 PlayerState.created_poems
# Array of Poem Resource 对象
# ════════════════════════════════════════════════════════════════
var created_poems: Array = []

# ════════════════════════════════════════════════════════════════
# 意象 — 原 Database.imaginaries_detail
# key: uuid (如 "snow"), value: Imaginary Resource
# ════════════════════════════════════════════════════════════════
var imaginaries_detail: Dictionary = {}

# ════════════════════════════════════════════════════════════════
# 世界 / 时间 — 原 GameState
# ════════════════════════════════════════════════════════════════
var year: float = 745.0
var current_era: String = ""
var is_game_over: bool = false
var death_cause: String = ""
var ratio_time: float = 0.0
var mood: float = 0.5

# ════════════════════════════════════════════════════════════════
# 时间引擎 — 原 TimeService
# total_days_elapsed: 整数真理之源（不从 float year 反推）
# tick_checkpoint: 上次发射时间信号的检查点（可从 total_days 恢复）
# ════════════════════════════════════════════════════════════════
var total_days_elapsed: int = 0
var tick_checkpoint: int = 0

# ════════════════════════════════════════════════════════════════
# 叙事计数 — PlotController 用，每次事件显示时 +1
# ════════════════════════════════════════════════════════════════
var event_counter: int = 0

# ════════════════════════════════════════════════════════════════
# NPC 关系数据 — NPCDocument 运行时属性的持久化快照
# key: target_tag (如 "libai", "hushang"), value: Dictionary
#   { "leverage_keys": [...], "help_count": 0,
#     "person_state": "not_meet", "intro_keys": [...] }
# save 时从 NPCDocument 实例快照，load 时恢复到 NPCDocument 实例。
# ════════════════════════════════════════════════════════════════
var npc_relations: Dictionary = {}


# ════════════════════════════════════════════════════════════════
# 序列化 / 反序列化
# ════════════════════════════════════════════════════════════════

## 将当前状态序列化为可 JSON 序列化的 Dictionary。
## 注意：created_poems 和 imaginaries_detail 包含 Resource，不做深度序列化，
## 仅保留 uuid 列表用于存档标识（后续 save/load 系统完善后可扩展）。
func to_dict() -> Dictionary:
	# 从 NPCDocument 实例快照当前关系数据
	_snapshot_npc_relations()
	var d := {
		"properties": _copy_dict(properties),
		"emotions": _copy_dict(emotions),
		"flags": _copy_dict(flags),
		"traits": traits.duplicate(),
		"player_name": player_name,
		"current_location": current_location,
		"ambition_uuid": ambition_uuid,
		"ambition_start_days": ambition_start_days,
		"current_action_tags": current_action_tags.duplicate(),
		"last_action_tags": last_action_tags.duplicate(),
		"created_poem_uuids": _extract_uuids(created_poems),
		"imaginary_uuids": imaginaries_detail.keys(),
		"npc_relations": _copy_dict(npc_relations),
		"year": year,
		"current_era": current_era,
		"is_game_over": is_game_over,
		"death_cause": death_cause,
		"ratio_time": ratio_time,
		"mood": mood,
		"stay_place": stay_place,
		"total_days_elapsed": total_days_elapsed,
		"tick_checkpoint": tick_checkpoint,
		"event_counter": event_counter,
	}
	return d


## 从 Dictionary 恢复状态。
## 注意：created_poems 和 imaginaries_detail 的 Resource 对象需要外部注入
## （Database 的对应字典中可查到完整 Resource）。
func from_dict(d: Dictionary) -> void:
	properties = _safe_dict(d, "properties")
	emotions = _safe_dict(d, "emotions")
	flags = _safe_dict(d, "flags")
	traits = _safe_array_str(d, "traits")
	player_name = d.get("player_name", "杜甫")
	current_location = d.get("current_location", "yong_zhou")
	ambition_uuid = d.get("ambition_uuid", "")
	ambition_start_days = d.get("ambition_start_days", -1)
	current_action_tags = _safe_array_str(d, "current_action_tags")
	last_action_tags = _safe_array_str(d, "last_action_tags")
	# created_poems / imaginaries_detail 需要外部注入，from_dict 不处理 Resource
	npc_relations = _safe_dict(d, "npc_relations")
	# NPC 关系数据恢复到 NPCDocument 实例（调用方需在 Database 就绪后调用 restore_npc_relations_to_documents()）
	year = d.get("year", 745.0)
	current_era = d.get("current_era", "")
	is_game_over = d.get("is_game_over", false)
	death_cause = d.get("death_cause", "")
	ratio_time = d.get("ratio_time", 0.0)
	mood = d.get("mood", 0.5)
	stay_place = d.get("stay_place", "xishi")
	total_days_elapsed = d.get("total_days_elapsed", 0)
	tick_checkpoint = d.get("tick_checkpoint", 0)
	event_counter = d.get("event_counter", 0)


# ════════════════════════════════════════════════════════════════
# 内部工具
# ════════════════════════════════════════════════════════════════

func _copy_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[k] = src[k]
	return out


func _safe_dict(d: Dictionary, key: String) -> Dictionary:
	var val = d.get(key, {})
	if val is Dictionary:
		return val.duplicate()
	return {}


func _safe_array_str(d: Dictionary, key: String) -> Array[String]:
	var val = d.get(key, [])
	if val is Array:
		var out: Array[String] = []
		for v in val:
			if v is String:
				out.append(v)
		return out
	return []


func _extract_uuids(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if item is Resource and "uuid" in item:
			out.append(item.uuid)
	return out


# ════════════════════════════════════════════════════════════════
# NPC 关系数据持久化桥接
# ════════════════════════════════════════════════════════════════

## 将 npc_relations 快照数据推回到 NPCDocument 实例。
## 应在 Database 加载完成后调用（存档加载流程中）。
func restore_npc_relations_to_documents() -> void:
	if npc_relations.is_empty():
		Logging.info("GameSaveData: npc_relations 为空，跳过 NPCDocument 关系恢复")
		return
	var docs: Dictionary = Database.get_npc_document_all()
	for target_tag in npc_relations:
		var data: Dictionary = npc_relations[target_tag]
		var doc = docs.get(target_tag)
		if doc == null:
			Logging.info("GameSaveData: NPCDocument '%s' 不存在，跳过关系恢复（数据仍保留在 npc_relations 中）" % target_tag)
			continue
		doc.leverage_keys = data.get("leverage_keys", [])
		doc.help_count = data.get("help_count", 0)
		doc.person_state = data.get("person_state", "not_meet")
		doc.intro_keys = data.get("intro_keys", [])
		Logging.info("GameSaveData: 恢复 '%s' 关系数据 → help=%d, leverage=%d, intro=%d, state=%s" % [target_tag, doc.help_count, doc.leverage_keys.size(), doc.intro_keys.size(), doc.person_state])

## 从所有已加载的 NPCDocument 实例快照关系数据到 npc_relations。
func _snapshot_npc_relations() -> void:
	var docs: Dictionary = Database.get_npc_document_all()
	for target_tag in docs:
		var doc = docs[target_tag]
		if doc == null:
			continue
		npc_relations[target_tag] = {
			"leverage_keys": doc.leverage_keys.duplicate(),
			"help_count": doc.help_count,
			"person_state": doc.person_state,
			"intro_keys": doc.intro_keys.duplicate(),
		}
	Logging.info("GameSaveData: _snapshot_npc_relations 快照 %d 个目标" % npc_relations.size())
