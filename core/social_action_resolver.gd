@tool
class_name SocialActionResolver extends RefCounted

# ═══════════════════════════════════════════════════════════
# SocialActionResolver — 社交行动解析器
# 纯静态工具类，在事件触发前为 context 注入 social_data
# （威胁/交好按钮所需的事件 ID）
# ═══════════════════════════════════════════════════════════

# ── 唯一入口 ─────────────────────────────────────────────

static func enrich_context(ev: BaseEvent, ev_name: String, context: Dictionary) -> Dictionary:
	if not context.has("main_tag") or str(context["main_tag"]).is_empty():
		return context

	# 1. relation_target 推导
	var target_tag := _derive_relation_target(context["main_tag"])
	if target_tag.is_empty():
		return context

	# 2. 查询把柄
	var leverage_keys: Array = RelationFlagManager.get_leverage_keys(target_tag)
	if leverage_keys.is_empty():
		return context

	# 3. 三级事件 ID 匹配
	var threaten_id := _resolve_threaten_id(leverage_keys)
	var do_favor_id := _resolve_do_favor_id(leverage_keys)

	# 4. 路由决策：根据 threaten/do_favor 是否存在注入不同 interrupt_event
	var has_threaten := not threaten_id.is_empty()
	var has_do_favor := not do_favor_id.is_empty()

	if has_threaten and has_do_favor:
		# both 存在 → 注入 social_data + router interrupt
		context["social_data"] = {
			"threaten": threaten_id,
			"do_favor": do_favor_id,
			"target_tag": target_tag,
			"origin_event_key": ev_name
		}
		context["interrupt_event"] = {
			"text": "社交行动",
			"event_key": "event_social_router"
		}
		Logging.info("[SocialActionResolver] both threaten(%s) + do_favor(%s) → router" % [threaten_id, do_favor_id])

	elif has_threaten:
		# 仅 threaten
		context["interrupt_event"] = {
			"text": "威胁",
			"event_key": threaten_id
		}
		Logging.info("[SocialActionResolver] only threaten → %s" % threaten_id)

	elif has_do_favor:
		# 仅 do_favor
		context["interrupt_event"] = {
			"text": "交好",
			"event_key": do_favor_id
		}
		Logging.info("[SocialActionResolver] only do_favor → %s" % do_favor_id)

	else:
		# 都没有 → 不注入任何东西
		Logging.info("[SocialActionResolver] no threaten nor do_favor matched, skip inject")

	# 5. return
	return context


# ── relation_target 推导 ─────────────────────────────────

static func _derive_relation_target(main_tag: String) -> String:
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var candidate := ENUMS.to_relation_str(target_enum_value)
		if main_tag.to_lower().begins_with(candidate):
			return candidate
	Logging.info("[SocialActionResolver] main_tag '%s' 未匹配任何 RELATION_TARGET" % main_tag)
	return ""


# ── 旷达状态检测 ─────────────────────────────────────────

static func _get_kuangda_state() -> String:
	return KuangdaState.current()


# ── 威胁事件 ID 三级匹配 ─────────────────────────────────

static func _resolve_threaten_id(leverage_keys: Array) -> String:
	var all_events: Dictionary = Database.get_all_events_iterator()

	# 层1: 针对每个把柄 key 精确匹配
	for lk in leverage_keys:
		var candidate := "event_threaten_" + str(lk)
		if all_events.has(candidate):
			return candidate

	# 层2: 旷达状态匹配
	var kuangda_state := _get_kuangda_state()
	if not kuangda_state.is_empty():
		var candidate := "event_threaten_" + kuangda_state
		if all_events.has(candidate):
			return candidate

	# 层3: 通用回退
	if all_events.has("event_threaten_generic"):
		return "event_threaten_generic"

	Logging.err("[SocialActionResolver] 威胁事件三级匹配全部失败, leverage_keys=%s" % str(leverage_keys))
	return ""


# ── 交好事件 ID 三级匹配 ─────────────────────────────────

static func _resolve_do_favor_id(leverage_keys: Array) -> String:
	var all_events: Dictionary = Database.get_all_events_iterator()

	# 层1: 针对每个把柄 key 精确匹配
	for lk in leverage_keys:
		var candidate := "event_do_favor_" + str(lk)
		if all_events.has(candidate):
			return candidate

	# 层2: 旷达状态匹配
	var kuangda_state := _get_kuangda_state()
	if not kuangda_state.is_empty():
		var candidate := "event_do_favor_" + kuangda_state
		if all_events.has(candidate):
			return candidate

	# 层3: 通用回退
	if all_events.has("event_do_favor"):
		return "event_do_favor"

	Logging.err("[SocialActionResolver] 交好事件三级匹配全部失败, leverage_keys=%s" % str(leverage_keys))
	return ""
