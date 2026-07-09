@tool
class_name PickNpcByPlaceOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════════
# PickNpcByPlaceOperator — 根据当前驻留地点随机选择匹配的 NPC
#
# DSL 语法:
#   pick_npc_by_place(key=npc_target; state=know_about)
#   pick_npc_by_place(key=npc_target)           # 不按 person_state 过滤
#
# 参数:
#   key:    必填 — 选中的 NPC tag 存入 context 的 key
#   state:  可选 — 额外按 person_state 过滤（如 know_about）
#
# 行为:
#   1. 读取 PlayerState.stay_place 获取当前驻留地点
#   2. 遍历 Database.npc_document 所有已注册的 NPCDocument
#   3. 过滤：doc.preferred_places 包含当前地点
#   4. 若 state 参数非空：过滤 doc.person_state == state
#   5. 随机选一个 NPC tag，存入 context[key]
#   6. 若无符合条件的 NPC，写入 warning 日志，context[key] 置空
# ═══════════════════════════════════════════════════════════════

## 选中 NPC 的 tag 存入 context 的 key（如 "npc_target"）
@export var key_stored_context: String = "npc_target"

## 可选 — 额外按 person_state 过滤
## 如 "know_about" / "inner_circle" / "blood_oath"
## 空字符串 = 不按 person_state 过滤
@export var state: String = ""


func init(_context: Dictionary) -> Dictionary:
	# ── 校验 ──
	if key_stored_context.is_empty():
		Logging.err("PickNpcByPlaceOperator.init: key_stored_context 为空，跳过")
		return _context

	# 1. 读取当前驻留地点
	var current_place: String = PlayerState.stay_place
	if current_place.is_empty():
		Logging.err("PickNpcByPlaceOperator.init: PlayerState.stay_place 为空，跳过")
		return _context

	Logging.info("PickNpcByPlaceOperator.init: 当前驻留地点=%s, 目标 context key=%s" % [current_place, key_stored_context])

	# 2. 收集匹配的候选人
	var candidates: Array[String] = []
	var all_docs: Dictionary = Database.get_npc_document_all()

	for target_tag: String in all_docs:
		var doc = all_docs[target_tag]
		if doc == null:
			continue

		# 3. 过滤 preferred_places
		var places: Array = doc.preferred_places if doc.has("preferred_places") else []
		if places.is_empty():
			Logging.debug("PickNpcByPlaceOperator: 跳过 %s（preferred_places 为空）" % target_tag)
			continue
		if not current_place in places:
			Logging.debug("PickNpcByPlaceOperator: 跳过 %s（preferred_places=%s，不含 %s）" % [target_tag, str(places), current_place])
			continue

		# 4. 可选：按 person_state 过滤
		if not state.is_empty():
			var person_state_val = RelationFlagManager.get_person_state(target_tag)
			if person_state_val != state:
				Logging.debug("PickNpcByPlaceOperator: 跳过 %s（person_state=%s，需要 %s）" % [target_tag, person_state_val, state])
				continue

		candidates.append(target_tag)
		Logging.debug("PickNpcByPlaceOperator: 候选人 +%s" % target_tag)

	if candidates.is_empty():
		Logging.warn("PickNpcByPlaceOperator.init: 在地点 '%s' 无符合条件的 NPC（state 过滤=%s）" % [current_place, state if not state.is_empty() else "(无过滤)"])
		_context[key_stored_context] = ""
		return _context

	# 5. 随机选一个
	candidates.shuffle()
	var chosen: String = candidates[0]
	Logging.info("PickNpcByPlaceOperator.init: 在地点 '%s' 随机选中 NPC=%s（候选人: %d）" % [current_place, chosen, candidates.size()])

	_context[key_stored_context] = chosen
	return _context


func operate() -> void:
	"""所有选择逻辑在 init() 中完成"""
	pass


func describe_preview() -> String:
	var desc = "在当前驻留地点中随机选人"
	if not state.is_empty():
		desc += "（state=%s）" % state
	desc += " → context[%s]" % key_stored_context
	return desc
