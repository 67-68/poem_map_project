class_name SubActionExecutor extends RefCounted
## 子行动执行器 — 从原 _on_sub_action_picked 提取的纯静态管线
##
## 输入：action_uuid（选中的子行动 UUID）+ VolatileState.action_state（pending 上下文）
## 输出：执行完整的 cost → possibility → operators → scan_events 链路
##
## 消费方：NpcActionButton._on_clicked()

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
	if not _sub_cost_ops.is_empty():
		_sub_cost_ctx["current_action"] = sub_action
		for r in _sub_cost_ops:
			if r and r.has_method("init"):
				_sub_cost_ctx = r.init(_sub_cost_ctx)
		Logging.info("SubActionExecutor.execute: sub-action '%s' cost archetype init (%d ops), ctx keys=%s" % [sub_action.name if sub_action else "NULL", _sub_cost_ops.size(), str(_sub_cost_ctx.keys())])
	
	# ── Step 2: sub-action action_results.init() ──
	var _sub_act_ctx: Dictionary = {}
	if sub_action and sub_action.action_results and not sub_action.action_results.is_empty():
		_sub_act_ctx["current_action"] = sub_action
		for r in sub_action.action_results:
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
		Logging.info("SubActionExecutor.execute: sub-action '%s' cost archetype operate (%d ops) — outcome=%s" % [sub_action.name if sub_action else "NULL", _sub_cost_ops.size(), _sub_outcome])
	
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
		# 追加 sub_uuid + sub_tags（bucket 路由用）
		PlayerState.current_action_tags.append(selected_uuid)
		for tag in sub_tags:
			PlayerState.current_action_tags.append(tag)
		
		# 注入 npc_target 到 context
		var npc_name := _extract_npc_name_from_tags(PlayerState.current_action_tags)
		var npc_target: String = _sub_cost_ctx.get("npc_target", state.npc_target)
		var required_tags: Array[String] = []
		for tag in PlayerState.current_action_tags:
			if tag.begins_with("actor:npc:") or tag.begins_with("social:"):
				required_tags.append(tag)
		Logging.info("SubActionExecutor.execute: SUCCESS — sub-action tags now: %s required=%s npc_target='%s'" % [str(PlayerState.current_action_tags), str(required_tags), npc_target])
		
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
