class_name SubActionExecutor extends RefCounted
## 子行动执行器 — 从原 _on_sub_action_picked 提取的纯静态管线
##
## 输入：action_uuid（选中的子行动 UUID）+ VolatileState.action_state（pending 上下文）
## 输出：执行完整的 cost → possibility → operators → imaginary_grant → scan_events 链路
##
## 消费方：NpcActionButton._on_clicked()

const _ImaginaryGrantChance = preload("res://core/model/imaginary_grant_chance.gd")
const _Imaginary = preload("res://core/model/imaginary.gd")

## 执行子行动完整管线。读取 VolatileState 中的 pending 数据，
## 独立完成 cost init/operate → possibility 投骰 → action_results → scan_events。
static func execute(selected_uuid: String, state: VolatileState.VolatileActionState) -> void:
	Logging.info("SubActionExecutor.execute: ═══ ENTER selected_uuid=%s pending_main_tag=%s pending_outcome=%s ═══" % [
		selected_uuid, state.pending_main_tag, state.pending_outcome
	])
	Logging.info("SubActionExecutor.execute: [地点DEBUG] ENTER时 stay_place='%s', place_mismatch=%s, required_place='%s', required_place_name='%s'" % [
		PlayerState.stay_place, str(state.selected_entity_place_mismatch), state.selected_entity_required_place, state.selected_entity_required_place_name
	])
	
	if selected_uuid.is_empty():
		Logging.err("SubActionExecutor.execute: selected_uuid is empty, aborting")
		state.clear()
		return
	
	# ── 异地行动：执行前消耗 1 天 + 切换 stay_place ──
	if state.selected_entity_place_mismatch and not state.selected_entity_required_place.is_empty():
		Logging.info("SubActionExecutor.execute: [地点DEBUG] 异地行动触发 — 消耗 1 天前往 '%s'(%s), 当前 stay_place='%s'" % [state.selected_entity_required_place_name, state.selected_entity_required_place, PlayerState.stay_place])
		# 🐛 修复：异地旅行 1 天不仅要推进日历，还要从玩家时间池扣除
		PlayerState.append_stat("_time", -1)
		TimeService.advance_time(1)
		PlayerState.stay_place = state.selected_entity_required_place
		Logging.info("SubActionExecutor.execute: [地点DEBUG] stay_place 赋值后验证: PlayerState.stay_place='%s', GameSave.data.stay_place='%s'" % [PlayerState.stay_place, GameSave.data.stay_place])
	else:
		Logging.info("SubActionExecutor.execute: [地点DEBUG] 非异地行动 — 不切换地点. mismatch=%s required_place='%s'" % [str(state.selected_entity_place_mismatch), state.selected_entity_required_place])
	
	# ── 查找子 action ──
	var sub_action: Action = Database.get_action(selected_uuid) as Action
	var sub_main_tag: String = ""
	var sub_fallback: String = ""
	var sub_tags: Array[String] = []
	
	if sub_action:
		sub_fallback = sub_action.fallback_event_uuid
		sub_tags = sub_action.action_tags.duplicate()
		
		if sub_action is SceneAction:
			sub_main_tag = (sub_action as SceneAction).main_tag
		else:
			sub_main_tag = ""
		Logging.info("SubActionExecutor.execute: sub-action '%s' tags=%s, fallback='%s', main_tag='%s'" % [selected_uuid, str(sub_tags), sub_fallback, sub_main_tag])
	else:
		Logging.warn("SubActionExecutor.execute: sub-action '%s' not found in Database, falling back to parent data" % selected_uuid)
		sub_main_tag = state.pending_main_tag
		sub_fallback = state.pending_fallback
		sub_tags = state.pending_tags.duplicate()

	# ── lead_to_event 快速通道：跳过全部执行管线（cost/possibility/day_consumed/scan_events），直接推送事件 ──
	if sub_action and not sub_action.lead_to_event.is_empty():
		Logging.info("SubActionExecutor.execute: lead_to_event 快速通道 — 跳过执行管线，直接推送事件 '%s' for sub-action '%s'" % [sub_action.lead_to_event, selected_uuid])
		EventBus.push_event.emit(sub_action.lead_to_event, {})
		state.clear()
		return

	# ── 重复行动检测 ──
	var _sub_identifying_tags: Array[String] = []
	if not sub_main_tag.is_empty():
		_sub_identifying_tags.append(sub_main_tag)
	_sub_identifying_tags.append_array(sub_tags)
	PlayerState._is_repeated_action = PlayerState.is_action_repeated(_sub_identifying_tags)
	Logging.info("SubActionExecutor.execute: _is_repeated_action=%s for sub tags=%s" % [str(PlayerState._is_repeated_action), str(_sub_identifying_tags)])
	
	# ── Step 1: cost archetype — Phase A: init only ──
	ActionManager.begin_action_batch()
	var _sub_cost_ops := sub_action.get_cost_operators() if sub_action and sub_action.has_method("get_cost_operators") else []
	var _sub_cost_ctx: Dictionary = {}
	var _sub_identity: String = selected_uuid
	if sub_action and not sub_action.topic.is_empty():
		_sub_identity = sub_action.topic
	if not _sub_cost_ops.is_empty():
		PlayerState.push_cost_context(_sub_identity)
		_sub_cost_ctx["current_action"] = sub_action
		for r in _sub_cost_ops:
			if r and r.has_method("init"):
				_sub_cost_ctx = r.init(_sub_cost_ctx)
		Logging.info("SubActionExecutor.execute: sub-action '%s' cost archetype init (%d ops), ctx keys=%s identity=%s" % [sub_action.name if sub_action else "NULL", _sub_cost_ops.size(), str(_sub_cost_ctx.keys()), _sub_identity])
	
	# ── Step 2: sub-action action_results.init()（合并 archetype universal_result DSL）──
	var _sub_merged_results: Array = sub_action.get_all_action_results() if sub_action else []
	var _sub_act_ctx: Dictionary = {}
	if not _sub_merged_results.is_empty():
		_sub_act_ctx["current_action"] = sub_action
		for r in _sub_merged_results:
			if r and r.has_method("init"):
				_sub_act_ctx = r.init(_sub_act_ctx)
	
	# ── Step 3: outcome 判定 ──
	var _sub_outcome: String = "success"
	var _sub_effective_possibility: int = sub_action.get_possibility_int() if sub_action else 100
	if sub_action and sub_action.dynamic_pos_set:
		_sub_effective_possibility = sub_action.dynamic_possibility
		Logging.info("SubActionExecutor.execute: sub-action 使用 dynamic_possibility=%d（替换配置的 %d）" % [_sub_effective_possibility, sub_action.get_possibility_int()])
	if sub_action and _sub_effective_possibility < 100:
		var roll: int = randi() % 101
		if roll > _sub_effective_possibility:
			_sub_outcome = "failure"
			Logging.info("SubActionExecutor.execute: sub-action '%s' possibility FAIL (roll=%d > %d)" % [sub_action.name, roll, _sub_effective_possibility])
		else:
			Logging.info("SubActionExecutor.execute: sub-action '%s' possibility PASS (roll=%d <= %d)" % [sub_action.name, roll, _sub_effective_possibility])
	
	# 🆕 注入 current_action_id（供 ActionMatchRequirement 条件匹配）
	GameSave.data.current_action_id = selected_uuid
	
	# ── Step 4: cost archetype — Phase B: operate ──
	if not _sub_cost_ops.is_empty():
		for r in _sub_cost_ops:
			if r:
				r.operate()
		PlayerState.pop_cost_context()
		Logging.info("SubActionExecutor.execute: sub-action '%s' cost archetype operate (%d ops) — outcome=%s identity=%s" % [sub_action.name if sub_action else "NULL", _sub_cost_ops.size(), _sub_outcome, _sub_identity])
	
	# ── Step 5: 执行父 action 的 operators ──
	for r in state.pending_results:
		r.operate()
	Logging.info("SubActionExecutor.execute: 执行父 action %d 个 operators" % state.pending_results.size())
	
	# ── Step 6: 时间消耗 ──
	var total_cost := ActionManager.get_action_day_cost(sub_action, state.pending_parent_day_consumed)
	if total_cost > 0:
		PlayerState.append_stat("_time", -total_cost)
		TimeService.advance_time(total_cost)
		Logging.info("SubActionExecutor.execute: sub-action '%s' day_consumed=%f, total_cost=%d" % [sub_action.name if sub_action else "NULL", ActionManager.effective_day_consumed(sub_action, state.pending_parent_day_consumed), total_cost])
	
	# 🆕 清除 current_action_id（ActionMatchRequirement 条件匹配结束）
	GameSave.data.current_action_id = ""
	
	ActionManager.end_action_batch()
	ActionManager.get_focus_controller().notify_click()
	
	# ── Step 7: 分支 — 成功 / 失败 ──
	if _sub_outcome == "success":
		# 🐛 修复：删除直接的 _sub_merged_results.operate() 执行，避免 success archetype operators 被执行两次。
		# archetype operators 统一交由 fallback 事件的 RandomEvent.init() 从 context 注入并随事件选项执行。
		
		# 追加 sub_uuid + sub_tags（bucket 路由用）
		PlayerState.current_action_tags.append(selected_uuid)
		for tag in sub_tags:
			PlayerState.current_action_tags.append(tag)
		
		# 注入 npc_target 到 context（在 if/else 外部使用）
		var npc_name := _extract_npc_name_from_tags(PlayerState.current_action_tags)
		var npc_target: String = _sub_cost_ctx.get("npc_target", state.npc_target)
		var required_tags: Array[String] = []
		for tag in PlayerState.current_action_tags:
			if tag.begins_with("actor:npc:") or tag.begins_with("social:"):
				required_tags.append(tag)
		Logging.info("SubActionExecutor.execute: SUCCESS — sub-action tags now: %s required=%s npc_target='%s'" % [str(PlayerState.current_action_tags), str(required_tags), npc_target])
		
		# 🆕 Step 7a.5: 意象获取抽奖（在 scan_events 之前，保证意象事件先入队列）
		_try_imaginary_grant(sub_action, state)

		var context = {
			'main_tag': sub_main_tag,
			'fallback_event_uuid': sub_fallback,
			'tag_match_mode': 'all',
			'required_tags': required_tags,
			'npc_name': npc_name,
			'npc_target': npc_target,
			'archetype_base': selected_uuid,
			'outcome': "success",
		}
		Logging.info("SubActionExecutor.execute: [地点DEBUG] scan_events前 stay_place='%s', context archetype_base='%s'" % [PlayerState.stay_place, selected_uuid])
		EventManager.scan_events(0, context)
		Logging.info("SubActionExecutor.execute: [地点DEBUG] scan_events后 stay_place='%s'" % PlayerState.stay_place)
		
		# sub-action success 后启动 defer
		#breakpoint
		if sub_action and sub_action.defer_config and not sub_action.defer_config.xun_defered.is_empty():
			Logging.info("SubActionExecutor.execute: sub-action '%s' 检测到 defer_config，启动 defer npc_target='%s'" % [sub_action.uuid, npc_target])
			ActionManager.start_defer(sub_action, npc_target)
	else:
		Logging.info("SubActionExecutor.execute: FAILURE — 执行 sub_action.failed_result")
		if sub_action and sub_action.failed_result:
			sub_action.failed_result.operate()
		else:
			Logging.warn("SubActionExecutor.execute: FAILURE 但 sub_action.failed_result 为空，fallback 到 EventBus.request_event_key('%s')" % sub_fallback)
			EventBus.request_event_key.emit(sub_fallback, {})
	
	# ── 更新 last_action_tags + 清理 ──
	PlayerState.last_action_tags = _sub_identifying_tags.duplicate()
	Logging.info("SubActionExecutor.execute: 更新 last_action_tags=%s" % str(PlayerState.last_action_tags))
	
	state.clear()
	Logging.info("SubActionExecutor.execute: 执行完毕，VolatileState 已清理")


## 从 current_action_tags 中提取 NPC 中文名
static func _extract_npc_name_from_tags(tags: Array) -> String:
	for tag in tags:
		if tag.begins_with("actor:npc:"):
			var npc_tag = tag.trim_prefix("actor:npc:")
			if npc_tag.is_empty():
				continue
			var doc = Database.get_npc_document(npc_tag)
			if doc != null and not doc.name.is_empty():
				Logging.info("SubActionExecutor._extract_npc_name_from_tags: '%s' → '%s'" % [npc_tag, doc.name])
				return doc.name
			else:
				Logging.debug("SubActionExecutor._extract_npc_name_from_tags: '%s' 无中文名，回退到 tag" % npc_tag)
				return npc_tag
	return ""


# ════════════════════════════════════════════════════════════════
# 🆕 意象获取抽奖系统
# ════════════════════════════════════════════════════════════════

const FALLBACK_IMAGINARY_EVENT: String = "imaginary_gain_fallback"

## 意象获取入口：解析 grants → 加权 roll → 随机选意象 → 授予 + 排队叙事事件。
## 子行动优先使用自己的 grants，为空时继承父行动的 grants。
static func _try_imaginary_grant(sub_action: Action, state: VolatileState.VolatileActionState) -> void:
	Logging.info("SubActionExecutor._try_imaginary_grant: ═══ ENTER sub_action='%s' ═══" % (sub_action.uuid if sub_action else "NULL"))
	if not sub_action:
		Logging.info("SubActionExecutor._try_imaginary_grant: sub_action is null, 跳过")
		return

	# ── 解析父 action ──
	var parent_action: Action = null
	var parent_uuid := _resolve_parent_uuid(sub_action)
	if not parent_uuid.is_empty():
		parent_action = Database.get_action(parent_uuid) as Action
		Logging.info("SubActionExecutor._try_imaginary_grant: 父 action = '%s' (%s)" % [parent_uuid, "found" if parent_action else "NOT FOUND"])

	# ── 解析 grants（子优先 → 父继承 → 旧字段 fallback）──
	var grants: Array = sub_action.resolve_imaginary_grants(parent_action)
	if grants.is_empty():
		Logging.info("SubActionExecutor._try_imaginary_grant: 无有效 grants，跳过意象获取")
		return
	Logging.info("SubActionExecutor._try_imaginary_grant: 解析到 %d 个 grant 条目" % grants.size())

	# ── 加权单次 Roll ──
	var total_pct: int = 0
	for g in grants:
		if g is _ImaginaryGrantChance:
			total_pct += (g as _ImaginaryGrantChance).get_possibility_int()

	if total_pct <= 0:
		Logging.info("SubActionExecutor._try_imaginary_grant: 总概率=0%%，跳过")
		return
	if total_pct > 100:
		Logging.err("SubActionExecutor._try_imaginary_grant: 总概率=%d%% > 100%%，截断为100%%" % total_pct)
		total_pct = 100

	var roll: int = randi() % 101
	Logging.info("SubActionExecutor._try_imaginary_grant: roll=%d, total_pct=%d" % [roll, total_pct])

	if roll >= total_pct:
		Logging.info("SubActionExecutor._try_imaginary_grant: roll=%d 落在空区间(%d~100)，不触发意象获取" % [roll, total_pct])
		return

	# ── 找到命中的 grant ──
	var accumulated: int = 0
	var hit_grant: ImaginaryGrantChance = null
	for g in grants:
		if g is _ImaginaryGrantChance:
			var gc := g as _ImaginaryGrantChance
			accumulated += gc.get_possibility_int()
			Logging.info("SubActionExecutor._try_imaginary_grant: 区间检查 type='%s' prob=%d accumulated=%d roll=%d" % [gc.imaginary_type, gc.get_possibility_int(), accumulated, roll])
			if roll < accumulated:
				hit_grant = gc
				break

	if not hit_grant:
		Logging.err("SubActionExecutor._try_imaginary_grant: 加权 roll 未命中任何 grant（roll=%d total=%d），跳过" % [roll, total_pct])
		return

	Logging.info("SubActionExecutor._try_imaginary_grant: 🎯 命中 type='%s'" % hit_grant.imaginary_type)

	# ── 按 type 过滤意象 → 随机选一个 ──
	var picked := _pick_imaginary_by_type(hit_grant.imaginary_type)
	if picked.is_empty():
		Logging.warn("SubActionExecutor._try_imaginary_grant: type='%s' 无候选意象，跳过" % hit_grant.imaginary_type)
		return

	var base_uuid: String = picked.get("uuid", "")
	var imag_name: String = picked.get("name", base_uuid)
	var imag_hint: String = picked.get("get_hint", "")
	var imag_type: String = picked.get("type", hit_grant.imaginary_type)

	Logging.info("SubActionExecutor._try_imaginary_grant: 选中意象 '%s' (name=%s, type=%s, hint='%s')" % [base_uuid, imag_name, imag_type, imag_hint])

	# ── 授予意象（写入 Database）──
	EventBus.request_add_imaginary.emit(base_uuid, {})
	Logging.info("SubActionExecutor._try_imaginary_grant: 已发射 request_add_imaginary('%s')" % base_uuid)

	# ── 推送叙事事件（队列模式：request_event_key，不打断当前流）──
	var event_uuid: String = _resolve_imaginary_event(base_uuid)
	var event_context := {
		"imaginary_uuid": base_uuid,
		"imaginary_name": imag_name,
		"imaginary_type": imag_type,
		"imaginary_gain_hint": imag_hint,
	}
	Logging.info("SubActionExecutor._try_imaginary_grant: 队列推送意象事件 '%s' context=%s" % [event_uuid, str(event_context)])
	EventBus.request_event_key.emit(event_uuid, event_context)


## 加权单次 Roll：遍历 grants，累积概率，找到 roll 命中的 grant。
## 返回命中的 ImaginaryGrantChance，若所有区间都未命中则返回 null。
## 注意：此方法不直接调用，已内联到 _try_imaginary_grant 中以保持日志可读性。
static func _roll_grant(grants: Array, roll: int) -> _ImaginaryGrantChance:
	var accumulated: int = 0
	for g in grants:
		if g is _ImaginaryGrantChance:
			var gc := g as _ImaginaryGrantChance
			accumulated += gc.get_possibility_int()
			if roll < accumulated:
				return gc
	return null


## 加载意象定义表（复用 RollImaginaryOperator 的同款逻辑）。
static var _cached_imaginary_defs: Dictionary = {}
static var _defs_loaded: bool = false

static func _load_imaginary_defs() -> Dictionary:
	if _defs_loaded:
		return _cached_imaginary_defs

	var file := FileAccess.open("res://tools/data/imaginary_definitions.json", FileAccess.READ)
	if not file:
		Logging.err("SubActionExecutor._load_imaginary_defs: 无法打开 imaginary_definitions.json")
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		Logging.err("SubActionExecutor._load_imaginary_defs: JSON 解析失败")
		return {}

	_cached_imaginary_defs = parsed
	_defs_loaded = true
	Logging.info("SubActionExecutor._load_imaginary_defs: 成功加载 %d 条意象定义" % _cached_imaginary_defs.size())
	return _cached_imaginary_defs


## 从 imaginary_definitions.json 中按 type 过滤，随机选一个。
## 返回 {uuid, name, type, get_hint} 字典；type 无候选时返回空字典。
static func _pick_imaginary_by_type(target_type: String) -> Dictionary:
	Logging.info("SubActionExecutor._pick_imaginary_by_type: 筛选 type='%s'" % target_type)

	var defs := _load_imaginary_defs()
	if defs.is_empty():
		Logging.err("SubActionExecutor._pick_imaginary_by_type: 定义表为空")
		return {}

	var candidates: Array[Dictionary] = []
	for uuid in defs:
		var entry: Dictionary = defs[uuid]
		var entry_type: String = str(entry.get("type", ""))
		if entry_type == target_type:
			candidates.append({
				"uuid": str(uuid),
				"name": str(entry.get("name", uuid)),
				"type": entry_type,
				"get_hint": str(entry.get("get_hint", "")),
				"level": entry.get("level", 1),
			})

	if candidates.is_empty():
		Logging.warn("SubActionExecutor._pick_imaginary_by_type: type='%s' 无候选意象" % target_type)
		return {}

	Logging.info("SubActionExecutor._pick_imaginary_by_type: 找到 %d 个 type='%s' 的候选意象" % [candidates.size(), target_type])
	candidates.shuffle()
	var picked: Dictionary = candidates[0]
	Logging.info("SubActionExecutor._pick_imaginary_by_type: 随机选中 '%s' (name=%s, level=%d)" % [picked.get("uuid"), picked.get("name"), picked.get("level")])
	return picked


## 解析意象专属事件 uuid："imaginary_gain_{base_uuid}"。
## 如果专属事件不存在，返回 FALLBACK_IMAGINARY_EVENT。
static func _resolve_imaginary_event(base_uuid: String) -> String:
	var specific_uuid := "imaginary_gain_" + base_uuid
	var ev = Database.resolve(specific_uuid)
	if ev != null:
		Logging.info("SubActionExecutor._resolve_imaginary_event: 找到专属事件 '%s'" % specific_uuid)
		return specific_uuid
	Logging.info("SubActionExecutor._resolve_imaginary_event: 专属事件 '%s' 不存在，使用 fallback '%s'" % [specific_uuid, FALLBACK_IMAGINARY_EVENT])
	return FALLBACK_IMAGINARY_EVENT


## 从子 action 的 parent_action 字段（或 sub_actions 反向查找）解析父 action uuid。
## 子 action 若是通过 CSV 生成的，其 parent_action 列明确指定了父 uuid。
static func _resolve_parent_uuid(sub_action: Action) -> String:
	# 方案 1: 全局扫描 Database 中所有 action，查找 sub_actions 包含 sub_action.uuid 的父 action
	if not sub_action or sub_action.uuid.is_empty():
		return ""

	var all_actions := Database.get_actions_all()
	for parent_id in all_actions:
		var parent := Database.get_action(parent_id) as Action
		if parent and parent.sub_actions.has(sub_action.uuid):
			Logging.info("SubActionExecutor._resolve_parent_uuid: '%s' 的父 action = '%s'（反向查找）" % [sub_action.uuid, parent.uuid])
			return parent.uuid

	Logging.info("SubActionExecutor._resolve_parent_uuid: '%s' 无父 action（反向查找未命中）" % sub_action.uuid)
	return ""
