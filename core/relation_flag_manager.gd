@tool
class_name RelationFlagManager extends RefCounted

const _NPCDocument = preload("res://model/npc_document.gd")

# ═══════════════════════════════════════════════════════════
# RelationFlagManager — 泛型关系管理器（NPCDocument 属性驱动）
#
# 负责管理玩家与 NPC / 社会身份 之间的泛型关系状态。
# 底层基于 NPCDocument 的 @export 属性，不再使用 PlayerState flag 机制。
#
# ── 数据流 ──
#
#   写入: Operator → RelationFlagManager → NPCDocument.属性
#   读取: UI/Requirement → RelationFlagManager → NPCDocument.属性
#   持久化: GameSaveData._snapshot_npc_relations() → to_dict()
#          GameSaveData.restore_npc_relations_to_documents() ← from_dict()
#
# ── 支持的关系类型 ──
#
#   leverage (把柄/威胁):
#     玩家掌握了某个目标（NPC/身份）的把柄/黑料。
#     存储为 NPCDocument.leverage_keys: Array[String]
#     event_threaten_{TARGET_TAG} (通用) / event_threaten_{key} (具体)
#
#   help (帮助/交好):
#     玩家帮助过某个目标（NPC/身份）。
#     NPCDocument.help_count: int
#     event_help_{TARGET_TAG}
#
#   person_state (人物状态 / 关系层级):
#     玩家与某个目标的关系层级，四态线性状态机：
#       T0 not_meet ──→ T1 know_about ──→ T2 inner_circle ──→ T3 blood_oath
#     每级跃迁规则由外部 Operator/Action/Event 判责，
#     RelationFlagManager 只提供数据层原子函数：
#       upgrade_person_state(target_tag) — 自动升级到下一级
#       get_next_person_state(target_tag) — 查询下一级目标状态
#     NPCDocument.person_state: String
#
#   intro (引荐信):
#     玩家持有的该目标的引荐信 key。
#     NPCDocument.intro_keys: Array[String]
#
# ── 使用示例 ──
#
#   # 添加把柄
#   RelationFlagManager.add_leverage("TARGET_IDENTITY_QUANGUI", "quangui_corruption")
#
#   # 查询所有把柄 key
#   var keys = RelationFlagManager.get_leverage_keys("TARGET_IDENTITY_QUANGUI")
#
#   # 使用把柄（LIFO）
#   var result = RelationFlagManager.try_use_leverage("TARGET_IDENTITY_QUANGUI")
#   # → {consumed: true, leverage_key: "quangui_corruption", event_id: "event_threaten_quangui_corruption"}
#
#   # 人物状态 / 关系层级升级
#   RelationFlagManager.upgrade_person_state("libai")  # T0→T1 或 T1→T2 或 T2→T3，自动查下一级
#   var next = RelationFlagManager.get_next_person_state("libai")  # 查询下一级
#
# ═══════════════════════════════════════════════════════════

# ── 常量：event_id 前缀 ──
const EVENT_PREFIX_THREATEN: String = "event_threaten_"
const EVENT_PREFIX_HELP:     String = "event_help_"

# ── 常量：RELATION_TARGET 社会阶层分级 ──
## T1 市井，T2 文人，T3 权贵。用于 set_random_person_state 等 Operator 筛选。
const RELATION_TARGET_TIER = {
	"hushang": 1,
	"shenyi": 1,
	"gaoshi": 2,
	"wangwei": 2,
	"zhengqian": 2,
	"qingliu": 2,
	"libai": 3,
	"lilinfu": 3,
	"jiwen": 3,
	"youxiangfu": 3,
	"waiqi": 3,
	"yangguozhong": 3,
	"guoguofuren": 3,
}

# ── Dict 模拟 Enum：人物状态 / 关系层级（仅允许存入 str，不可使用 int/enum）──
## 五态线性状态机：
##   T-1: uncharted    — 玩家不知道此人存在（默认态）
##   T0:  not_meet     — 听闻/迷雾，节点不可直接交互
##   T1:  know_about   — 泛泛之交/脸熟，节点解锁，基础资源置换
##   T2:  inner_circle — 入幕之宾/核心圈，产出「势」和政治情报
##   T3:  blood_oath   — 生死之交/政治死党，无视规则以势碾敌
## 使用时通过 PERSON_STATE.UNCHARTED / .NOT_MEET / .KNOW_ABOUT / .INNER_CIRCLE / .BLOOD_OATH 引用。
const PERSON_STATE = {
	"UNCHARTED":    "uncharted",
	"NOT_MEET":     "not_meet",
	"KNOW_ABOUT":   "know_about",
	"INNER_CIRCLE": "inner_circle",
	"BLOOD_OATH":   "blood_oath",
}

## person_state 默认值
const DEFAULT_PERSON_STATE: String = "uncharted"

## person_state 层级序列表 — 用于 upgrade_person_state 推算下一级
const _PERSON_STATE_ORDER: Array[String] = ["uncharted", "not_meet", "know_about", "inner_circle", "blood_oath"]

# ── 离散 tier 倍率表（替代旧好感度连续倍率） ──
## 用于 get_tier_multiplier()，is_good=true 时取好属性列，false 时取坏属性列
const _TIER_MULTIPLIER_TABLE = {
	"uncharted":    {good = 0.0,  bad = 0.0},   # 无交互，不触发
	"not_meet":     {good = 0.0,  bad = 0.0},   # 无交互，不触发
	"know_about":   {good = 1.0,  bad = 1.0},   # 泛泛之交，公平交易
	"inner_circle": {good = 1.5,  bad = 0.67},  # 自己人，收益放大
	"blood_oath":   {good = 2.5,  bad = 0.4},   # 死党，一荣俱荣
}


# ═══════════════════════════════════════════════════════════
# 底层通用工具
# ═══════════════════════════════════════════════════════════

## 获取或动态创建 NPCDocument。
## 对于已在 Database.npc_document 中注册的 target → 直接返回。
## 对于不存在的 target → 动态创建 NPCDocument 并注册到 Database.npc_document。
static func _get_or_create_npc_doc(target_tag: String) -> NPCDocument:
	var doc = Database.get_npc_document(target_tag)
	if doc != null:
		return doc

	# 动态创建 NPCDocument（目标尚未有 .tres 文件时）
	doc = NPCDocument.new()
	doc.uuid = target_tag
	doc.name = target_tag
	doc.taste_id = ""
	doc.prop = {}
	doc.leverage_keys = [] as Array[String]
	doc.help_count = 0
	doc.person_state = DEFAULT_PERSON_STATE
	doc.intro_keys = [] as Array[String]
	doc.relate_to = [] as Array[String]
	Database.npc_document[target_tag] = doc
	Logging.info("RelationFlagManager: 动态创建 NPCDocument for '%s'（无对应 .tres 文件）" % target_tag)
	return doc

## 构建 event_id：event_{verb}_{target_tag}
static func _build_event_id(verb_prefix: String, target_tag: String) -> String:
	return verb_prefix + target_tag


# ═══════════════════════════════════════════════════════════
# 把柄 / 威胁 (Leverage) — NPCDocument.leverage_keys
# ═══════════════════════════════════════════════════════════

## 为目标追加一条把柄 key
static func add_leverage(target_tag: String, leverage_key: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	if leverage_key in doc.leverage_keys:
		Logging.info("RelationFlagManager: leverage key '%s' already exists for %s, skip duplicate" % [leverage_key, target_tag])
		return
	doc.leverage_keys.append(leverage_key)
	Logging.info("RelationFlagManager: leverage +'%s' for %s (total=%d)" % [leverage_key, target_tag, doc.leverage_keys.size()])

## 获取目标当前的所有把柄 key
static func get_leverage_keys(target_tag: String) -> Array:
	var doc = _get_or_create_npc_doc(target_tag)
	return doc.leverage_keys

## 检查目标是否有把柄
static func has_leverage(target_tag: String) -> bool:
	var doc = _get_or_create_npc_doc(target_tag)
	return not doc.leverage_keys.is_empty()

## 按 key 精确匹配并移除一条把柄
## 返回 true 表示成功消费，false 表示未找到
static func consume_leverage(target_tag: String, leverage_key: String) -> bool:
	var doc = _get_or_create_npc_doc(target_tag)
	if doc.leverage_keys.is_empty():
		Logging.info("RelationFlagManager: consume_leverage failed — no leverage for %s" % target_tag)
		return false

	var idx = doc.leverage_keys.find(leverage_key)
	if idx == -1:
		Logging.info("RelationFlagManager: consume_leverage failed — key '%s' not found in %s" % [leverage_key, target_tag])
		return false

	doc.leverage_keys.remove_at(idx)
	Logging.info("RelationFlagManager: consume_leverage '%s' from %s, remaining=%d" % [leverage_key, target_tag, doc.leverage_keys.size()])
	return true

## 尝试使用把柄（LIFO: pop_back 弹出最近一条）
## 返回: {consumed: bool, leverage_key: String, event_id: String}
##   event_id 优先尝试 event_threaten_{key}（具体事件），不存在则降级到 event_threaten_{target_tag}（通用事件）
static func try_use_leverage(target_tag: String) -> Dictionary:
	var doc = _get_or_create_npc_doc(target_tag)
	if doc.leverage_keys.is_empty():
		Logging.info("RelationFlagManager: try_use_leverage — no leverage for %s" % target_tag)
		return {consumed = false, leverage_key = "", event_id = ""}

	var key: String = doc.leverage_keys.pop_back()

	# 优先查找具体事件: event_threaten_{key}
	var specific_event_id = _build_event_id(EVENT_PREFIX_THREATEN, key)
	var event_id: String = ""

	if Database.get_all_events_iterator().has(specific_event_id):
		event_id = specific_event_id
		Logging.info("RelationFlagManager: try_use_leverage — specific event found: %s" % specific_event_id)
	else:
		# 降级到通用事件: event_threaten_{target_tag}
		event_id = _build_event_id(EVENT_PREFIX_THREATEN, target_tag)
		Logging.info("RelationFlagManager: try_use_leverage — specific event not found (%s), fallback to generic: %s" % [specific_event_id, event_id])

	Logging.info("RelationFlagManager: try_use_leverage consumed '%s' from %s, remaining=%d" % [key, target_tag, doc.leverage_keys.size()])
	return {consumed = true, leverage_key = key, event_id = event_id}

## 清除目标的所有把柄
static func clear_leverage(target_tag: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	doc.leverage_keys.clear()
	Logging.info("RelationFlagManager: leverage cleared for %s" % target_tag)

## 获取威胁事件的约定 event_id（通用降级事件）
##
## 结果遵循命名约定：event_threaten_{TARGET_TAG}
## 此 event_id 对应 data/1_core_rules/relations/ 下的威胁事件文件。
static func get_threaten_event_id(target_tag: String) -> String:
	return _build_event_id(EVENT_PREFIX_THREATEN, target_tag)


# ═══════════════════════════════════════════════════════════
# 帮助 / 交好 (Help) — NPCDocument.help_count
# ═══════════════════════════════════════════════════════════

## 🆕 NPC 关系升级所需的 help 次数基数（未受修饰器影响）
## 默认: 2 次 help 可升级一级（know_about → inner_circle → blood_oath 各需 2 次）
const DEFAULT_HELP_PER_UPGRADE: int = 2

## 获取指定 NPC 升级所需的有效 help 次数（经理念修饰器修正）。
## relation_speed_abs: 减少绝对次数（如 -1 → 2-1=1）
## relation_speed_pct: 减少百分比次数（如 -50% → 2×0.5=1）
static func get_help_requirement(target_tag: String) -> int:
	var base: int = DEFAULT_HELP_PER_UPGRADE
	var speed := ModifierRegistry.get_relation_speed(target_tag)
	
	if speed.abs > 0:
		base = maxi(base - speed.abs, 1)
		Logging.info("RelationFlagManager: get_help_requirement(%s) 理念 abs -%d → %d" % [target_tag, speed.abs, base])
	
	if speed.pct > 0.0:
		base = maxi(int(float(base) * (1.0 - speed.pct)), 1)
		Logging.info("RelationFlagManager: get_help_requirement(%s) 理念 pct -%.0f%% → %d" % [target_tag, speed.pct * 100.0, base])
	
	return base


## 检查 target 是否已达到下一次升级的 help 次数要求（经理念修饰器修正）。
static func is_help_sufficient(target_tag: String) -> bool:
	var requirement: int = get_help_requirement(target_tag)
	var current: int = get_help(target_tag)
	var sufficient := current >= requirement
	Logging.info("RelationFlagManager: is_help_sufficient(%s) help=%d, required=%d → %s" % [target_tag, current, requirement, "✅" if sufficient else "❌"])
	return sufficient


## 为目标添加 N 次帮助
static func add_help(target_tag: String, amount: int = 1) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	doc.help_count += amount
	Logging.info("RelationFlagManager: help ++%d for %s (total=%d)" % [amount, target_tag, doc.help_count])

## 获取目标当前的帮助次数
static func get_help(target_tag: String) -> int:
	var doc = _get_or_create_npc_doc(target_tag)
	return doc.help_count

## 检查目标是否有帮助记录
static func has_help(target_tag: String) -> bool:
	var doc = _get_or_create_npc_doc(target_tag)
	return doc.help_count > 0

## 清除目标的所有帮助记录
static func clear_help(target_tag: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	doc.help_count = 0
	Logging.info("RelationFlagManager: help cleared for %s" % target_tag)

## 获取交好事件的约定 event_id
##
## 结果遵循命名约定：event_help_{TARGET_TAG}
## 此 event_id 对应 data/1_core_rules/relations/ 下的帮助/交好事件文件。
static func get_help_event_id(target_tag: String) -> String:
	return _build_event_id(EVENT_PREFIX_HELP, target_tag)


# ═══════════════════════════════════════════════════════════
# 人物状态 (Person State) — NPCDocument.person_state
# ═══════════════════════════════════════════════════════════
#
# 四态线性状态机：
#   T0: not_meet ──(打探/引荐)──→ T1: know_about ──(3旬熬)──→ T2: inner_circle ──(献祭)──→ T3: blood_oath
#
# 每级跃迁条件由外部 Operator/Action/Event 判责，
# RelationFlagManager 只提供数据层原子操作：
#   upgrade_person_state(target_tag) — 自动查找并升级到下一级
#   get_next_person_state(target_tag) — 查询下一级目标状态
#
# 底层存储为 NPCDocument.person_state: String。
# 外部调用必须传递 PERSON_STATE dict 的值（如 PERSON_STATE.KNOW_ABOUT），
# 不可手写裸字符串字面量。
# ═══════════════════════════════════════════════════════════

## 内部：校验 state 值是否在 PERSON_STATE dict 的合法值列表中
static func _is_valid_person_state(state: String) -> bool:
	for valid_state in PERSON_STATE.values():
		if state == valid_state:
			return true
	return false

## 获取目标当前的人物状态
##
## 若 NPCDocument 不存在则动态创建（默认 "not_meet"）。
## 返回 PERSON_STATE 中的 str 值（如 "not_meet" / "know_about"）。
static func get_person_state(target_tag: String) -> String:
	var doc = _get_or_create_npc_doc(target_tag)
	# 校验已有值的合法性
	if _is_valid_person_state(doc.person_state):
		return doc.person_state
	# 非法值回退
	if not doc.person_state.is_empty():
		Logging.err("RelationFlagManager: person_state 读取到非法值 '%s' for %s，回退到默认值" % [doc.person_state, target_tag])
	doc.person_state = DEFAULT_PERSON_STATE
	return DEFAULT_PERSON_STATE

## 显式设置目标的人物状态
##
## @param state: 必须是 PERSON_STATE dict 值，如 PERSON_STATE.KNOW_ABOUT。
##               传入非法值时打 err 并拒绝写入。
static func set_person_state(target_tag: String, state: String) -> void:
	if not _is_valid_person_state(state):
		Logging.err("RelationFlagManager: set_person_state 收到非法 state='%s' for %s，拒绝写入。合法值: %s" % [state, target_tag, str(PERSON_STATE.values())])
		return
	var doc = _get_or_create_npc_doc(target_tag)
	doc.person_state = state
	Logging.info("RelationFlagManager: person_state set to '%s' for %s" % [state, target_tag])

## 便捷判断：目标当前状态是否等于指定值
##
## @param state: PERSON_STATE 值，如 PERSON_STATE.KNOW_ABOUT
static func is_person_state(target_tag: String, state: String) -> bool:
	var current = get_person_state(target_tag)
	var result = (current == state)
	if not result:
		Logging.info("RelationFlagManager: is_person_state(%s, %s) → false (current=%s)" % [target_tag, state, current])
	return result

## 获取所有已认识（状态 ≥ T1 know_about）的目标列表
##
## 遍历所有 RELATION_TARGET，返回 person_state 不是 not_meet 的 target。
## 即 T1(know_about) / T2(inner_circle) / T3(blood_oath) 都算"已认识"。
## 供 UI（如关系一览面板）调用。
static func get_known_targets() -> Array[String]:
	var known: Array[String] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		if target_tag.is_empty():
			continue
		var state = get_person_state(target_tag)
		if state != PERSON_STATE.NOT_MEET and state != "":
			known.append(target_tag)
	Logging.info("RelationFlagManager: get_known_targets → %d known out of %d total" % [known.size(), ENUMS.RELATION_TARGET.size()])
	return known

## 检查目标是否已存在 NPCDocument（不触发动态创建）
static func has_person_state_flag(target_tag: String) -> bool:
	return Database.get_npc_document(target_tag) != null

## 清除目标的 person_state（重置为默认值）
static func clear_person_state(target_tag: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	doc.person_state = DEFAULT_PERSON_STATE
	Logging.info("RelationFlagManager: person_state reset to '%s' for %s" % [DEFAULT_PERSON_STATE, target_tag])


# ═══════════════════════════════════════════════════════════
# 关系层级 (Tier) 倍率系统 — 离散 4 态乘法表（替代旧好感度连续倍率）
# ═══════════════════════════════════════════════════════════
#
# 架构概要：
#   PlayerState.append_stat() 在属性变更后调用 get_tier_multiplier()，
#   根据当前事件 target_tag 的 person_state (T0-T3) 返回离散倍率。
#   不再使用 before_property_change 信号钩子。
#
# 好属性（玩家希望增加的）：
#   prestige, progress, talent, money, health
#
# 倍率规则（_TIER_MULTIPLIER_TABLE 常量已在上方定义）：
#   T0(not_meet):    无交互，倍率 0.0（不触发）
#   T1(know_about):  公平交易，倍率 1.0
#   T2(inner_circle): 自己人，好属性 1.5x / 坏属性 0.67x
#   T3(blood_oath):  死党，好属性 2.5x / 坏属性 0.4x
# ═══════════════════════════════════════════════════════════

## 硬编码的"好属性"对照表（key 为 Database.prop 的 uuid/name）
const GOOD_PROPS: Dictionary = {
	"prestige": true,
	"progress": true,
	"talent": true,
	"money": true,
	"health": true,
	"astuteness": true,
	"composure": true,
	"inspiration": true,
	"momentum": true,
}

## 硬编码的"坏属性"对照表
const BAD_PROPS: Dictionary = {}

## 获取 target 当前 tier 对应的属性倍率。
##
##   is_good=true  → 取 _TIER_MULTIPLIER_TABLE[tier].good
##   is_good=false → 取 _TIER_MULTIPLIER_TABLE[tier].bad
##   target_tag 为空或 state 不在表中 → 返回 1.0
static func get_tier_multiplier(target_tag: String, is_good: bool) -> float:
	if target_tag.is_empty():
		return 1.0
	var state = get_person_state(target_tag)
	var tier_data = _TIER_MULTIPLIER_TABLE.get(state, {})
	if tier_data.is_empty():
		Logging.info("RelationFlagManager: get_tier_multiplier — unknown state '%s' for %s, return 1.0" % [state, target_tag])
		return 1.0
	var multiplier = tier_data.good if is_good else tier_data.bad
	Logging.info("RelationFlagManager: get_tier_multiplier(%s, state=%s, is_good=%s) → %.2f" % [target_tag, state, is_good, multiplier])
	return multiplier


# ═══════════════════════════════════════════════════════════
# 关系层级升级 — 线性自动推进
# ═══════════════════════════════════════════════════════════

## 返回 target 当前状态下可跃迁到的下一级 person_state。
##
##   线性链表: not_meet → know_about → inner_circle → blood_oath → ""
##   若已是 T3 (blood_oath) 则返回空字符串。
static func get_next_person_state(target_tag: String) -> String:
	var current = get_person_state(target_tag)
	var idx = _PERSON_STATE_ORDER.find(current)
	if idx == -1 or idx >= _PERSON_STATE_ORDER.size() - 1:
		Logging.info("RelationFlagManager: get_next_person_state(%s) — current='%s' 已是最高级或无下一级" % [target_tag, current])
		return ""
	var next_state = _PERSON_STATE_ORDER[idx + 1]
	Logging.info("RelationFlagManager: get_next_person_state(%s) — current='%s' → next='%s'" % [target_tag, current, next_state])
	return next_state

## 升级 target 的 person_state 到下一级。
##
##   自动调用 get_next_person_state() 推算目标状态，执行替换。
##   返回 true 表示升级成功，false 表示已是最高级或状态异常。
##
##   外部调用方负责判责（金钱/物品/Title 检查），本函数只做数据操作。
static func upgrade_person_state(target_tag: String) -> bool:
	var next_state = get_next_person_state(target_tag)
	if next_state.is_empty():
		Logging.info("RelationFlagManager: upgrade_person_state(%s) — 已是最高级，无法再升级" % target_tag)
		return false
	set_person_state(target_tag, next_state)
	Logging.info("RelationFlagManager: upgrade_person_state(%s) — 升级完成 → '%s'" % [target_tag, next_state])
	return true


# ═══════════════════════════════════════════════════════════
# 引荐信 (Intro) — NPCDocument.intro_keys
# ═══════════════════════════════════════════════════════════

## 为目标追加一条引荐信 key
static func add_intro(target_tag: String, intro_key: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	if intro_key in doc.intro_keys:
		Logging.info("RelationFlagManager: intro key '%s' already exists for %s, skip duplicate" % [intro_key, target_tag])
		return
	doc.intro_keys.append(intro_key)
	Logging.info("RelationFlagManager: intro +'%s' for %s (total=%d)" % [intro_key, target_tag, doc.intro_keys.size()])

## 获取目标当前的所有引荐信 key
static func get_intro_keys(target_tag: String) -> Array:
	var doc = _get_or_create_npc_doc(target_tag)
	return doc.intro_keys

## 检查目标是否有引荐信
static func has_intro(target_tag: String) -> bool:
	var doc = _get_or_create_npc_doc(target_tag)
	return not doc.intro_keys.is_empty()

## 按 key 精确匹配并移除一条引荐信
## 返回 true 表示成功消费，false 表示未找到
static func consume_intro(target_tag: String, intro_key: String) -> bool:
	var doc = _get_or_create_npc_doc(target_tag)
	if doc.intro_keys.is_empty():
		Logging.info("RelationFlagManager: consume_intro failed — no intro for %s" % target_tag)
		return false

	var idx = doc.intro_keys.find(intro_key)
	if idx == -1:
		Logging.info("RelationFlagManager: consume_intro failed — key '%s' not found in %s" % [intro_key, target_tag])
		return false

	doc.intro_keys.remove_at(idx)
	Logging.info("RelationFlagManager: consume_intro '%s' from %s, remaining=%d" % [intro_key, target_tag, doc.intro_keys.size()])
	return true

## 清除目标的所有引荐信
static func clear_intro(target_tag: String) -> void:
	var doc = _get_or_create_npc_doc(target_tag)
	doc.intro_keys.clear()
	Logging.info("RelationFlagManager: intro cleared for %s" % target_tag)


# ═══════════════════════════════════════════════════════════
# 聚合查询 — 一次性获取所有目标的关系数据
# ═══════════════════════════════════════════════════════════

## 批量获取所有关系数据，供风闻面板等 UI 调用。
##
## @param targets: target_tag 数组，如 ["libai", "youxiangfu", ...]
##                 来源: ENUMS.RELATION_TARGET.keys() → to_lower()
## @return Dictionary: {target_tag: {leverage_keys: Array[String],
##                                    help: int,
##                                    person_state: String,
##                                    intro_keys: Array[String]}}
## 无数据的目标返回空列表 / 0 / 默认值，不报错。
static func get_all_relations(targets: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for target_tag in targets:
		result[target_tag] = {
			leverage_keys = get_leverage_keys(target_tag),
			intro_keys = get_intro_keys(target_tag),
			help = get_help(target_tag),
			person_state = get_person_state(target_tag),
		}
	Logging.info("RelationFlagManager: get_all_relations queried %d targets" % targets.size())
	return result
