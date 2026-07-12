class_name NPCSelector extends RefCounted

# ═══════════════════════════════════════════════════════════
# NPCSelector — NPC 选择器静态工具
#
# 封装三种选人模式，内部调用 NPCAvailabilityManager 做天数过滤。
# 供 PickNpcOperator / PickNpcByPlaceOperator 统一委托。
#
# 三种模式:
#   select_by_place  → 按地点筛选 NPC
#   select_random    → 从所有 RELATION_TARGET 中随机选
#   select_related   → 从 source NPC 的 relate_to 中选
#
# 所有方法返回:
#   String — 选中 NPC 的 target_tag
#   空串   — 无符合条件的 NPC
# ═══════════════════════════════════════════════════════════

## 按地点筛选 NPC + 天数可用性检查。
## @param target_places: Array[String] — 目标地点列表（如 ["pingkangfang", "huangcheng"]）
## @param state: String — 可选 person_state 过滤，空串=不过滤
## @param state_compare: String — "eq" / "gte" / ""（不过滤）
## @return String — 选中 NPC 的 target_tag，空串=无候选
static func select_by_place(target_places: Array[String], state: String = "", state_compare: String = "eq") -> String:
	if target_places.is_empty():
		Logging.err("NPCSelector.select_by_place: target_places 为空")
		return ""

	var today: int = TimeService.current_day
	var candidates: Array[String] = []
	var all_docs: Dictionary = Database.get_npc_document_all()

	for target_tag: String in all_docs:
		var doc = all_docs[target_tag]
		if doc == null:
			continue

		# 天数可用性检查
		if not NPCAvailabilityManager.is_available(doc, today):
			Logging.debug("NPCSelector: 跳过 %s（day=%d 不可用）" % [target_tag, today])
			continue

		# 过滤 preferred_places
		var npc_places: Array = doc.preferred_places if doc.has("preferred_places") else []
		if npc_places.is_empty():
			Logging.debug("NPCSelector: 跳过 %s（preferred_places 为空）" % target_tag)
			continue

		var place_match := false
		for tp in target_places:
			if tp in npc_places:
				place_match = true
				break
		if not place_match:
			Logging.debug("NPCSelector: 跳过 %s（preferred_places=%s，不含 %s）" % [target_tag, str(npc_places), str(target_places)])
			continue

		# 可选 person_state 过滤
		if not state.is_empty():
			var current_state = RelationFlagManager.get_person_state(target_tag)
			if not _state_matches(current_state, state, state_compare):
				Logging.debug("NPCSelector: 跳过 %s（state=%s，需要 %s, cmp=%s）" % [target_tag, current_state, state, state_compare])
				continue

		candidates.append(target_tag)

	if candidates.is_empty():
		Logging.warn("NPCSelector.select_by_place: 在 %s 无候选 NPC（state=%s）" % [str(target_places), state])
		return ""

	candidates.shuffle()
	var chosen: String = candidates[0]
	Logging.info("NPCSelector.select_by_place: 在 %s 选中 NPC=%s（候选人: %d）" % [str(target_places), chosen, candidates.size()])
	return chosen


## 从所有 RELATION_TARGET 中随机选人 + 天数可用性检查。
## @param state: String — 可选 person_state 过滤，空串=不过滤
## @param state_compare: String — "eq" / "gte" / ""（不过滤）
## @return String — 选中 NPC 的 target_tag，空串=无候选
static func select_random(state: String = "", state_compare: String = "eq") -> String:
	var today: int = TimeService.current_day
	var candidates: Array[String] = []

	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		if target_tag.is_empty():
			continue

		# 天数可用性检查
		var doc = Database.get_npc_document(target_tag)
		if doc == null:
			Logging.debug("NPCSelector: 跳过 %s（无 NPCDocument）" % target_tag)
			continue
		if not NPCAvailabilityManager.is_available(doc, today):
			Logging.debug("NPCSelector: 跳过 %s（day=%d 不可用）" % [target_tag, today])
			continue

		# 可选 person_state 过滤
		if not state.is_empty():
			var current_state = RelationFlagManager.get_person_state(target_tag)
			if not _state_matches(current_state, state, state_compare):
				Logging.debug("NPCSelector: 跳过 %s（state=%s，需要 %s, cmp=%s）" % [target_tag, current_state, state, state_compare])
				continue

		candidates.append(target_tag)

	if candidates.is_empty():
		Logging.warn("NPCSelector.select_random: 无候选 NPC（state=%s）" % state)
		return ""

	candidates.shuffle()
	var chosen: String = candidates[0]
	Logging.info("NPCSelector.select_random: 选中 NPC=%s（候选人: %d）" % [chosen, candidates.size()])
	return chosen


## 从 source NPC 的 relate_to 中选人 + 天数可用性检查。
## @param source_tag: String — 源 NPC 的 target_tag
## @param state: String — 可选 person_state 过滤，空串=不过滤
## @param state_compare: String — "eq" / "gte" / ""（不过滤）
## @return String — 选中 NPC 的 target_tag，空串=无候选
static func select_related(source_tag: String, state: String = "", state_compare: String = "eq") -> String:
	if source_tag.is_empty():
		Logging.err("NPCSelector.select_related: source_tag 为空")
		return ""

	var doc = Database.get_npc_document(source_tag)
	if doc == null:
		Logging.err("NPCSelector.select_related: 未找到 NPC document for '%s'" % source_tag)
		return ""

	var relates: Array = doc.relate_to if doc.has("relate_to") else []
	if relates.is_empty():
		Logging.warn("NPCSelector.select_related: '%s' 的 relate_to 为空" % source_tag)
		return ""

	Logging.info("NPCSelector.select_related: source=%s，relate_to=%s" % [source_tag, str(relates)])

	var today: int = TimeService.current_day
	var candidates: Array[String] = []
	for candidate_tag in relates:
		# 天数可用性检查
		var candidate_doc = Database.get_npc_document(candidate_tag)
		if candidate_doc == null:
			Logging.debug("NPCSelector: 跳过 %s（无 NPCDocument）" % candidate_tag)
			continue
		if not NPCAvailabilityManager.is_available(candidate_doc, today):
			Logging.debug("NPCSelector: 跳过 %s（day=%d 不可用）" % [candidate_tag, today])
			continue

		if state.is_empty():
			candidates.append(candidate_tag)
		else:
			var current_state = RelationFlagManager.get_person_state(candidate_tag)
			if _state_matches(current_state, state, state_compare):
				candidates.append(candidate_tag)

	if candidates.is_empty():
		Logging.warn("NPCSelector.select_related: 无候选（state=%s）" % state)
		return ""

	candidates.shuffle()
	var chosen: String = candidates[0]
	Logging.info("NPCSelector.select_related: 选中 NPC=%s（候选人: %d）" % [chosen, candidates.size()])
	return chosen


# ═══════════════════════════════════════════════════════════
# 内部工具
# ═══════════════════════════════════════════════════════════

## state_compare 匹配判断
static func _state_matches(current_state: String, target_state: String, compare: String) -> bool:
	match compare:
		"gte":
			var idx_current = _PERSON_STATE_ORDER.find(current_state)
			var idx_target = _PERSON_STATE_ORDER.find(target_state)
			if idx_current == -1 or idx_target == -1:
				return false
			return idx_current >= idx_target
		"eq", _:
			return current_state == target_state

const _PERSON_STATE_ORDER: Array[String] = ["uncharted", "not_meet", "know_about", "inner_circle", "blood_oath"]
