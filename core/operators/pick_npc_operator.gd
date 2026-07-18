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

## 可选 — true 时跳过 NPC 可用性检查（appear_days），用于"听人说起"等场景
@export var skip_availability: bool = false

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
		Logging.warn("PickNpcOperator.init: 无法选中 NPC（mode=%s），context[%s] 置空，设置 dynamic_possibility=0" % [mode, key_stored_context])
		_context[key_stored_context] = ""
		# 🆕 没有 NPC 可用时，设置 dynamic_possibility=0 让投骰必失败
		var current_action: Action = _context.get("current_action", null) if _context.has("current_action") else null
		if current_action != null:
			current_action.dynamic_possibility = 0
			Logging.info("PickNpcOperator.init: 设置 action '%s' dynamic_possibility=0（无候选 NPC）" % current_action.uuid)
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
	var desc = tr("CODE_PICK_NPC_OPERATOR_039C53C7AF") % mode
	if not state.is_empty():
		desc += "，state=%s" % state
	if not social_tag.is_empty():
		desc += "，tag=%s" % social_tag
	desc += " → context[%s]" % key_stored_context
	return desc


# ═══════════════════════════════════════════════════════════
# 三种选人模式 — 委托给 NPCSelector
# ═══════════════════════════════════════════════════════════

## mode=random: 从所有 RELATION_TARGET 中随机选人
func _pick_random() -> String:
	return NPCSelector.select_random(state, state_compare, skip_availability)


## mode=by_place: 根据地点筛选 NPC
func _pick_by_place() -> String:
	# 解析地点列表
	var target_places: Array[String] = []
	if not places.is_empty():
		for s in places.split(","):
			target_places.append(s.strip_edges())
	else:
		var current_place: String = PlayerState.stay_place
		if current_place.is_empty():
			Logging.err("PickNpcOperator: by_place 模式但 PlayerState.stay_place 为空")
			return ""
		target_places = [current_place]

	Logging.info("PickNpcOperator: by_place 模式，目标地点=%s, skip_availability=%s" % [str(target_places), str(skip_availability)])
	return NPCSelector.select_by_place(target_places, state, state_compare, skip_availability)


## mode=related: 从 source NPC 的 relate_to 中选人
func _pick_related(_context: Dictionary) -> String:
	if source_key.is_empty():
		Logging.err("PickNpcOperator: related 模式但 source_key 为空")
		return ""

	var source_tag: String = _context.get(source_key, "")
	if source_tag.is_empty():
		Logging.err("PickNpcOperator: related 模式，context[%s] 为空" % source_key)
		return ""

	return NPCSelector.select_related(source_tag, state, state_compare)
