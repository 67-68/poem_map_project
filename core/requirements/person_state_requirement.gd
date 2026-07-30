@tool
class_name PersonStateRequirement extends BaseRequirements
## PersonStateRequirement — 检查指定 NPC 的关系状态。
##
## @export npc_key:    NPC 的 target_tag（如 "tut_taoist"）。
## @export expected_state: 期望的状态（"not_meet"/"know_about"/"inner_circle"/"blood_oath"）。

@export var npc_key: String = ""
@export var expected_state: String = "know_about"

func compare(_player_state) -> bool:
	if npc_key.is_empty():
		Logging.err("PersonStateRequirement.compare: npc_key 为空，返回 false")
		return false
	var current := RelationFlagManager.get_person_state(npc_key)
	var result := current == expected_state
	Logging.info("PersonStateRequirement.compare: npc='%s', current='%s', expected='%s' → %s" % [npc_key, current, expected_state, str(result)])
	return result

func describe_requirement() -> String:
	if npc_key.is_empty():
		return ""
	return tr("CODE_PERSON_STATE_REQ_DESC") % [npc_key, expected_state]

func get_failed_hint() -> String:
	if npc_key.is_empty():
		return ""
	return tr("CODE_PERSON_STATE_REQ_FAILED") % npc_key
