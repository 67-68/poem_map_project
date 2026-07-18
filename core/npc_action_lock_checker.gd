## NpcActionLockChecker — Override 行动锁定判定器（纯静态 RefCounted）
##
## 仅用于 override action 场景：判断某个覆盖行动对特定 NPC 是否应被锁定。
## 锁定条件：
##   1. action_uuid 在 NPC.normal_actions 中
##   2. NPC.person_state < "know_about"（即 "not_meet"，因为 uncharted 已被调用方过滤）
##
## 消费方：PickerTapeAttachment._rebuild_right_panel_override_buttons()

@tool
class_name NpcActionLockChecker extends RefCounted

const _LOCK_THRESHOLD: String = "know_about"


## 返回 true = 该 action 应被锁定（灰色不可点击）
static func is_locked(action_uuid: String, npc_doc: NPCDocument) -> bool:
	if action_uuid.is_empty():
		Logging.info("NpcActionLockChecker.is_locked: action_uuid 为空 → 不锁定")
		return false
	if npc_doc == null:
		Logging.info("NpcActionLockChecker.is_locked: npc_doc 为空 → 不锁定")
		return false

	var in_normal := action_uuid in npc_doc.normal_actions
	var state := npc_doc.person_state
	if state.is_empty():
		state = RelationFlagManager.DEFAULT_PERSON_STATE

	var below_threshold := _person_state_rank(state) < _person_state_rank(_LOCK_THRESHOLD)
	var locked := in_normal and below_threshold

	Logging.info("NpcActionLockChecker.is_locked: action='%s' npc='%s' in_normal=%s state='%s' below_threshold=%s → locked=%s" % [
		action_uuid,
		npc_doc.name,
		str(in_normal),
		state,
		str(below_threshold),
		str(locked)
	])
	return locked


## 返回锁定原因字符串（供 toast / tooltip 展示）
static func get_lock_reason(action_uuid: String, npc_doc: NPCDocument) -> String:
	if npc_doc == null:
		return tr("CODE_NPC_ACTION_LOCK_CHECKER_ED757BE5DD")
	var npc_name := npc_doc.name if not npc_doc.name.is_empty() else npc_doc.uuid
	var reason := tr("CODE_NPC_ACTION_LOCK_CHECKER_71BC43506B") % npc_name
	Logging.info("NpcActionLockChecker.get_lock_reason: action='%s' npc='%s' → '%s'" % [action_uuid, npc_doc.name, reason])
	return reason


## 将 person_state 字符串转为排序索引（UNCHARTED=0, NOT_MEET=1, KNOW_ABOUT=2, ...）
static func _person_state_rank(state: String) -> int:
	match state:
		"uncharted":
			return 0
		"not_meet":
			return 1
		"know_about":
			return 2
		"inner_circle":
			return 3
		"blood_oath":
			return 4
		_:
			Logging.err("NpcActionLockChecker._person_state_rank: 未知 person_state='%s'，回退为 0" % state)
			return 0
