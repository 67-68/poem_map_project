@tool
class_name PickNpcOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# PickNpcOperator — 统一 NPC 选择器
#
# 三种模式（mode 参数）：
#   by_place:  根据 PlayerState.stay_place 筛选 NPC（preferred_places 匹配）
#   random:    从所有 RELATION_TARGET 中随机选人（不限地点）
#   related:   从 source_key 指定 NPC 的 relate_to 列表中选人
#
# DSL 语法:
#   pick_npc(mode=by_place; key=npc_target)
#   pick_npc(mode=by_place; places=pingkangfang,huangcheng; state=uncharted; key=npc_target; social_tag=social:acquaint)
#   pick_npc(mode=random; key=npc_target; social_tag=social:leverage)
#   pick_npc(mode=random; state=uncharted; key=npc_target)
#   pick_npc(mode=related; source_key=host_npc; state=not_meet; key=letter_target)
#
# 参数:
#   mode:       必填 — "by_place" / "random" / "related"
#   key:        必填 — 选中的 NPC tag 存入 context 的 key
#   places:     by_place 可选 — 逗号分隔的地点列表（如 "pingkangfang,huangcheng"）
#              不传则使用 PlayerState.stay_place
#   state:      可选 — 额外按 person_state 过滤
#   state_compare: 可选 — "eq"(默认) / "gte" / ""（不过滤）
#   source_key: related 必填 — 读取其 relate_to 的 NPC context key
#   social_tag: 可选 — operate() 时注入到 current_action_tags 的社交标签
# ═══════════════════════════════════════════════════════════

## 选择模式
@export var mode: String = "by_place"

## 选中 NPC 的 tag 存入 context 的 key
@export var key_stored_context: String = "npc_target"

## by_place 模式：逗号分隔的地点列表（可选）
## 空字符串 = 使用 PlayerState.stay_place
@export var places: String = ""

## 可选 — 额外按 person_state 过滤。空字符串 = 不过滤
@export var state: String = ""

## 状态比较模式 — "eq"(默认) / "gte" / ""（不过滤）
@export var state_compare: String = "eq"

## related 模式：从哪个 context key 读取源 NPC tag
@export var source_key: String = ""

## 可选 — operate() 时注入到 current_action_tags 的社交标签
## 如 "social:acquaint"
@export var social_tag: String = ""

## init 阶段捕获的 context 快照（供 operate 使用）
var _captured_context: Dictionary = {}


func init(_context: Dictionary) -> Dictionary:
	_captured_context = _context.duplicate()

	# ── 校验 ──
	if key_stored_context.is_empty():
		Logging.err("PickNpcOperator.init: key_stored_context 为空，跳过")
		return _context

	var target_tag: String = ""
	match mode:
		"random":
			target_tag = _pick_random()
		"by_place":
			target_tag = _pick_by_place()
		"related":
			target_tag = _pick_related(_context)
		_:
			Logging.err("PickNpcOperator.init: 未知 mode='%s'，跳过" % mode)
			_context[key_stored_context] = ""
			return _context

	if target_tag.is_empty():
		Logging.warn("PickNpcOperator.init: 无法选中 NPC（mode=%s），context[%s] 置空" % [mode, key_stored_context])
		_context[key_stored_context] = ""
		return _context

	_context[key_stored_context] = target_tag
	# 同步到 _captured_context 以便 operate 读取
	_captured_context[key_stored_context] = target_tag

	# 注入 NPC 中文显示名（供 fallback 事件 {@xxx_name} 插值使用）
	var doc = Database.get_npc_document(target_tag)
	if doc != null and not doc.name.is_empty():
		var name_key = key_stored_context + "_name"
		_context[name_key] = doc.name
		_captured_context[name_key] = doc.name
		Logging.info("PickNpcOperator.init: 注入显示名 %s → context[%s]" % [doc.name, name_key])
	else:
		Logging.debug("PickNpcOperator.init: %s 无中文名，使用 tag 回退" % target_tag)

	Logging.info("PickNpcOperator.init: mode=%s → 选中 NPC=%s，存入 context[%s]" % [mode, target_tag, key_stored_context])
	return _context


func operate() -> void:
	"""将 NPC tag + social_tag 注入 current_action_tags"""
	var npc_tag: String = _captured_context.get(key_stored_context, "")

	if npc_tag.is_empty():
		Logging.warn("PickNpcOperator.operate: context[%s] 为空，跳过 tag 注入" % key_stored_context)
		return

	# 注入 actor:npc:{target_tag}
	var full_npc_tag: String = "actor:npc:" + npc_tag
	if not full_npc_tag in PlayerState.current_action_tags:
		PlayerState.current_action_tags.append(full_npc_tag)
		Logging.info("PickNpcOperator.operate: 注入 npc tag='%s'" % full_npc_tag)

	# 注入 social_tag（如 social:acquaint）
	if not social_tag.is_empty():
		if not social_tag in PlayerState.current_action_tags:
			PlayerState.current_action_tags.append(social_tag)
			Logging.info("PickNpcOperator.operate: 注入 social tag='%s'" % social_tag)


func describe_preview() -> String:
	var desc = "选人（mode=%s）" % mode
	if not state.is_empty():
		desc += "，state=%s" % state
	if not social_tag.is_empty():
		desc += "，tag=%s" % social_tag
	desc += " → context[%s]" % key_stored_context
	return desc


# ═══════════════════════════════════════════════════════════
# 三种选人模式
# ═══════════════════════════════════════════════════════════

## mode=random: 从所有 RELATION_TARGET 中随机选人
func _pick_random() -> String:
	var candidates: Array[String] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		if target_tag.is_empty():
			continue

		# 可选 state 过滤
		if not state.is_empty():
			var current_state = RelationFlagManager.get_person_state(target_tag)
			if not _state_matches(current_state):
				Logging.debug("PickNpcOperator: 跳过 %s（state=%s，需要 %s）" % [target_tag, current_state, state])
				continue

		candidates.append(target_tag)

	if candidates.is_empty():
		Logging.warn("PickNpcOperator: random 模式无候选 NPC（state=%s）" % state)
		return ""

	candidates.shuffle()
	return candidates[0]


## mode=by_place: 根据地点筛选 NPC
func _pick_by_place() -> String:
	# 解析地点列表
	var target_places: Array[String] = []
	if not places.is_empty():
		target_places = places.split(",")
		for i in range(target_places.size()):
			target_places[i] = target_places[i].strip_edges()
	else:
		var current_place: String = PlayerState.stay_place
		if current_place.is_empty():
			Logging.err("PickNpcOperator: by_place 模式但 PlayerState.stay_place 为空")
			return ""
		target_places = [current_place]

	Logging.info("PickNpcOperator: by_place 模式，目标地点=%s" % str(target_places))

	# 遍历所有 NPCDocument
	var candidates: Array[String] = []
	var all_docs: Dictionary = Database.get_npc_document_all()

	for target_tag: String in all_docs:
		var doc = all_docs[target_tag]
		if doc == null:
			continue

		# 过滤 preferred_places
		var npc_places: Array = doc.preferred_places if doc.has("preferred_places") else []
		if npc_places.is_empty():
			Logging.debug("PickNpcOperator: 跳过 %s（preferred_places 为空）" % target_tag)
			continue

		var place_match := false
		for tp in target_places:
			if tp in npc_places:
				place_match = true
				break
		if not place_match:
			Logging.debug("PickNpcOperator: 跳过 %s（preferred_places=%s，不含 %s）" % [target_tag, str(npc_places), str(target_places)])
			continue

		# 可选 state 过滤
		if not state.is_empty():
			var current_state = RelationFlagManager.get_person_state(target_tag)
			if not _state_matches(current_state):
				Logging.debug("PickNpcOperator: 跳过 %s（state=%s，需要 %s）" % [target_tag, current_state, state])
				continue

		candidates.append(target_tag)

	if candidates.is_empty():
		Logging.warn("PickNpcOperator: by_place 模式在 %s 无候选 NPC（state=%s）" % [str(target_places), state])
		return ""

	candidates.shuffle()
	return candidates[0]


## mode=related: 从 source NPC 的 relate_to 中选人
func _pick_related(_context: Dictionary) -> String:
	if source_key.is_empty():
		Logging.err("PickNpcOperator: related 模式但 source_key 为空")
		return ""

	var source_tag: String = _context.get(source_key, "")
	if source_tag.is_empty():
		Logging.err("PickNpcOperator: related 模式，context[%s] 为空" % source_key)
		return ""

	var doc = Database.get_npc_document(source_tag)
	if doc == null:
		Logging.err("PickNpcOperator: related 模式，未找到 NPC document for '%s'" % source_tag)
		return ""

	var relates: Array = doc.relate_to if doc.has("relate_to") else []
	if relates.is_empty():
		Logging.warn("PickNpcOperator: '%s' 的 relate_to 为空" % source_tag)
		return ""

	Logging.info("PickNpcOperator: related 模式，source=%s，relate_to=%s" % [source_tag, str(relates)])

	# 过滤 + 随机选
	var candidates: Array[String] = []
	for candidate_tag in relates:
		if state.is_empty():
			candidates.append(candidate_tag)
		else:
			var current_state = RelationFlagManager.get_person_state(candidate_tag)
			if _state_matches(current_state):
				candidates.append(candidate_tag)

	if candidates.is_empty():
		Logging.warn("PickNpcOperator: related 模式无候选（state=%s）" % state)
		return ""

	candidates.shuffle()
	return candidates[0]


## state_compare 匹配判断
func _state_matches(current_state: String) -> bool:
	match state_compare:
		"gte":
			var idx_current = _PERSON_STATE_ORDER.find(current_state)
			var idx_target = _PERSON_STATE_ORDER.find(state)
			if idx_current == -1 or idx_target == -1:
				return false
			return idx_current >= idx_target
		"eq", _:
			return current_state == state

## 引用 PERSON_STATE_ORDER 用于 state_compare=gte
const _PERSON_STATE_ORDER: Array[String] = ["uncharted", "not_meet", "know_about", "inner_circle", "blood_oath"]
