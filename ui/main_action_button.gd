class_name MainActionButton extends SceneActionPanel
## 主行动按钮 — 父行动完整执行管线
##
## 覆写 _on_clicked()：cost archetype → possibility 投骰 → sub-action picker（写 VolatileState）→ scan_events
## 使用 main_action_button.tscn（与 action_button.tscn 结构相同，脚本指向本文件）


func _on_clicked() -> void:
	Logging.info("MainActionButton: BUTTON_PRESSED name=%s type=%s action_results=%d generator=%s" % [
		action.name if action else "NULL",
		action.get_class() if action else "NULL",
		action.action_results.size() if action and action.action_results else 0,
		"yes" if action and action.generator != null else "no"
	])
	
	# ── 快照：在 begin_action_batch 之前锁定 action 元数据 ──
	var _snap_is_scene := action is SceneAction
	var _snap_main_tag := ""
	var _snap_fallback := ""
	var _snap_tags: Array[String] = []
	var _snap_generator = action.generator
	var _snap_day_consumed: float = action.day_consumed
	if _snap_is_scene:
		var sa := action as SceneAction
		_snap_main_tag = sa.main_tag
		_snap_fallback = sa.fallback_event_uuid
		_snap_tags = sa.action_tags.duplicate()
	
	# ── Step 1: 投骰前执行 cost archetype（资源立即扣除）──
	ActionManager.begin_action_batch()
	var _cost_ops := action.get_cost_operators() if action.has_method("get_cost_operators") else []
	if not _cost_ops.is_empty():
		var _cost_ctx: Dictionary = {}
		for r in _cost_ops:
			if r and r.has_method("init"):
				_cost_ctx = r.init(_cost_ctx)
		for r in _cost_ops:
			if r:
				r.operate()
		Logging.info("MainActionButton: 执行 cost archetype (%d ops) for '%s'" % [_cost_ops.size(), action.name])
	ActionManager.end_action_batch()
	
	# ── Step 2: action_results.init() — 投骰前执行 ──
	var _act_ctx: Dictionary = {}
	var _act_ops = action.action_results if action.action_results else []
	_act_ctx["current_action"] = action
	for r in _act_ops:
		if r and r.has_method("init"):
			_act_ctx = r.init(_act_ctx)
	
	# ── Step 3: 判定 outcome ──
	var _outcome: String = "success"
	var _effective_possibility: int = action.get_possibility_int()
	if action.dynamic_pos_set:
		_effective_possibility = action.dynamic_possibility
		Logging.info("MainActionButton: 使用 dynamic_possibility=%d（替换配置的 %d，NPC 不可用）" % [_effective_possibility, action.get_possibility_int()])
	
	if _snap_generator == null and _effective_possibility < 100:
		var roll: int = randi() % 101
		if roll > _effective_possibility:
			_outcome = "failure"
			Logging.info("MainActionButton: possibility 未中签 (roll=%d, effective_possibility=%d)，outcome=%s" % [roll, _effective_possibility, _outcome])
	
	# ── Sub-action 检测 ──
	if _snap_is_scene and _snap_generator == null and action.sub_actions and not action.sub_actions.is_empty():
		# 写入 VolatileState
		VolatileState.action_state.pending_main_tag = _snap_main_tag
		VolatileState.action_state.pending_fallback = _snap_fallback
		VolatileState.action_state.pending_tags = _snap_tags.duplicate()
		VolatileState.action_state.pending_results = action.action_results.duplicate() if action.action_results else []
		VolatileState.action_state.pending_parent_day_consumed = action.day_consumed
		VolatileState.action_state.pending_outcome = _outcome
		VolatileState.action_state.selected_sub_action_uuid = ""
		
		var picker_data: Array[GameEntity] = []
		for sub_uuid in action.sub_actions:
			if sub_uuid.is_empty():
				Logging.warn("MainActionButton: sub_actions 包含空 UUID，跳过")
				continue
			var sub_action: Action = Database.get_action(sub_uuid) as Action
			if not sub_action:
				Logging.warn("MainActionButton: sub_actions 中 UUID '%s' 无法解析为 Action，跳过" % sub_uuid)
				continue
			
			# 🆕 Tutorial 子行动白名单过滤
			if not ActionManager.is_sub_action_tutorial_allowed(sub_uuid):
				Logging.info("MainActionButton: sub-action '%s' 不在 tutorial 子白名单中，跳过" % sub_uuid)
				continue
			
			# 🆕 全局黑名单过滤：子 Action 在黑名单中 → 不显示在 Picker
			if ActionManager.is_action_hidden(sub_uuid):
				Logging.info("MainActionButton: sub-action '%s' 在黑名单中，跳过" % sub_uuid)
				continue
			
			# Phase 1: HIDE 检查
			var _should_hide := false
			var archetype = Database.get_archetype_by_uuid(sub_action.uuid, "success")
			var success_ops: Array = []
			if archetype:
				success_ops = archetype.operators
			var fail_archetype = Database.get_archetype_by_uuid(sub_action.uuid, "failure")
			var fail_ops: Array = []
			if fail_archetype:
				fail_ops = fail_archetype.operators
			
			if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
				for req in sub_action.aciton_requirements:
					if req is TraitRequirement or req is FlagRequirement or req is NarrativeLockRequirement:
						if not req.compare(PlayerState):
							Logging.info("MainActionButton: sub-action '%s' HIDE — requirement type='%s' not met" % [sub_action.uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown"])
							_should_hide = true
							break
					elif req is PoemRequirement:
						# 🆕 PoemRequirement 不再 HIDE — 改为 GRAY（在 picker 中显示但标记不足）
						Logging.info("MainActionButton: sub-action '%s' PoemRequirement not met → 注入 GRAY reason (原 HIDE)" % sub_action.uuid)
			
			# 🆕 删除特殊资源 viability HIDE（ConsumeRandomLeverage / PoemReward 不再隐藏）
			# 改为在 picker 中用普通/特殊按钮过滤可见性
			
			if _should_hide:
				Logging.info("MainActionButton: sub-action '%s' 完全隐藏（门槛要求不满足），不进入 picker" % sub_action.uuid)
				continue
			
			# Phase 2: GRAY 检查
			var _gray_reasons: Array[String] = []
			
			if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
				for req in sub_action.aciton_requirements:
					if req is PropertyRequirement or req is EmotionRequirement or req is PropRangeRequirement or req is PoemRequirement:
						if not req.compare(PlayerState):
							var desc := req.describe_requirement() if req.has_method("describe_requirement") else ""
							var reason := desc if not desc.is_empty() else tr("CODE_MAIN_ACTION_BUTTON_13B937F5A7")
							_gray_reasons.append(reason)
							Logging.info("MainActionButton: sub-action '%s' GRAY — requirement type='%s' not met: '%s'" % [sub_action.uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown", reason])
			
			var cost_arch_check = Database.get_archetype_by_uuid(sub_action.uuid, "cost")
			if cost_arch_check and not cost_arch_check.operators.is_empty():
				var arch_cost_reasons := ActionManager.check_archetype_property_costs(cost_arch_check.operators)
				if not arch_cost_reasons.is_empty():
					for r in arch_cost_reasons:
						_gray_reasons.append(r)
					Logging.info("MainActionButton: sub-action '%s' GRAY — cost archetype check: %s" % [sub_action.uuid, str(arch_cost_reasons)])
			
			var sub_cost := ActionManager.get_action_day_cost(sub_action, action.day_consumed)
			if sub_cost > 0:
				var current_time := int(PlayerState.get_stat_val("time"))
				if current_time < sub_cost:
					var cost_detail := ActionManager.format_time_detail(action.day_consumed)
					var time_reason := tr("CODE_MAIN_ACTION_BUTTON_DC059CE490") % [current_time, cost_detail]
					_gray_reasons.append(time_reason)
					Logging.info("MainActionButton: sub-action '%s' GRAY — %s" % [sub_action.uuid, time_reason])
			
			# 构建 entity
			var entity := GameEntity.new({
				"uuid": sub_action.uuid,
				"name": sub_action.name,
				"description": sub_action.description if sub_action.description else ""
			})
			# 传递 icon 供 SubActionButton 展示
			if sub_action.icon:
				entity.set_meta("_action_icon", sub_action.icon)
			entity.set_meta("parent_main_tag", _snap_main_tag)
			entity.set_meta("operators", success_ops)

			# 🆕 判定是否"特殊"行动（cost archetype 含非 PropertyOperator）
			entity.set_meta("_is_special", _is_special_sub_action(sub_action))
			
			# 地点校验
			var _place_mismatch := RemoteActionFilterManager.is_action_remote(sub_action)
			if _place_mismatch:
				var _place_name := sub_action.get_required_place_name()
				var _req_place: String = sub_action.required_place
				entity.set_meta("_place_mismatch", true)
				entity.set_meta("_required_place_name", _place_name)
				entity.set_meta("_required_place", _req_place)
				Logging.info("MainActionButton: sub-action '%s' PLACE_MISMATCH — requires %s (%s), current=%s" % [sub_action.uuid, _place_name, _req_place, RemoteActionFilterManager.get_current_place()])
			else:
				entity.set_meta("_place_mismatch", false)
			
			if not _place_mismatch and not _gray_reasons.is_empty():
				var joined_reason := tr("CODE_MAIN_ACTION_BUTTON_46F4EC4498") + "、".join(_gray_reasons)
				entity.set_meta("_is_locked", true)
				entity.set_meta("_locked_reason", joined_reason)
				Logging.info("MainActionButton: sub-action '%s' 标记为灰化锁定, reason='%s'" % [sub_action.uuid, joined_reason])
			
			if fail_archetype:
				Logging.info("MainActionButton: failure archetype found for '%s' (%d ops)" % [sub_action.uuid, fail_ops.size()])
			else:
				Logging.info("MainActionButton: no failure archetype for '%s'" % sub_action.uuid)

			if sub_action:
				var preview = ActionHintBuilder.build_sub_action_preview(sub_action, success_ops, fail_ops, action.day_consumed)
				entity.set_meta("sub_action_preview", preview.vector)
				Logging.info("MainActionButton: sub_action_preview built for '%s' (%d chars)" % [sub_action.name, preview.vector.length()])
			else:
				entity.set_meta("sub_action_preview", "")

			picker_data.append(entity)
		
		Logging.info("MainActionButton: sub_actions 检测到 %d 个子行动，弹出 Picker" % picker_data.size())
		VolatileState.action_state.pending_on_checkbox_toggled = _on_picker_checkbox_toggled
		
		# 驻留（zhu_liu）自动勾选「显示异地行动」
		if action.uuid == "zhu_liu" and not RemoteActionFilterManager.get_show_remote():
			RemoteActionFilterManager.push_show_remote_override(true)
			VolatileState.action_state.did_auto_enable_remote = true
			Logging.info("MainActionButton: 驻留 zhu_liu → 自动开启「显示异地行动」(push snapshot)")
		EventBus.push_sub_action_picker.emit(picker_data, _on_sub_action_picked, null, VolatileState.action_state.pending_on_checkbox_toggled)
		return
	
	# ── 重复行动检测 ──
	var _identifying_tags: Array[String] = []
	if _snap_is_scene and not _snap_main_tag.is_empty():
		_identifying_tags.append(_snap_main_tag)
	_identifying_tags.append_array(_snap_tags)
	PlayerState._is_repeated_action = PlayerState.is_action_repeated(_identifying_tags)
	Logging.info("MainActionButton: _is_repeated_action=%s for identifying_tags=%s" % [str(PlayerState._is_repeated_action), str(_identifying_tags)])
	
	# ── 非 sub-action 路径：执行 action_results.operate() ──
	if not _act_ops.is_empty():
		for r in _act_ops:
			if r:
				r.operate()
		Logging.info("MainActionButton: 执行 action_results.operate() (%d ops) for '%s'" % [_act_ops.size(), action.name])
	
	# ── 时间消耗 ──
	if _snap_day_consumed > 0:
		var total_cost := ActionManager.get_action_day_cost(action)
		if total_cost > 0:
			PlayerState.append_stat("_time", -total_cost)
			TimeService.advance_time(total_cost)
			Logging.info("[MainActionButton] day_consumed=%f, total_cost=%d, 已扣除并推进日历" % [_snap_day_consumed, total_cost])
	
	ActionManager.get_focus_controller().notify_click()
	
	# ── Generator 消费 ──
	var had_generator := _snap_generator != null
	ActionManager.consume_generator(action)
	
	# ── Decision 点击后触发 UI 即时刷新 ──
	if action is Decision and action.allowed_count >= 0:
		EventBus.decision_clicked.emit()
	
	if had_generator:
		PlayerState.last_action_tags = _snap_tags.duplicate()
		Logging.info("MainActionButton: generator 路径，更新 last_action_tags=%s" % str(PlayerState.last_action_tags))
		return
	
	# ── 事件扫描 ──
	if _snap_is_scene:
		for tag in _snap_tags:
			PlayerState.current_action_tags.append(tag)
		
		var npc_name := _extract_npc_name_from_tags(PlayerState.current_action_tags)
		
		var context = {
			'main_tag': _snap_main_tag,
			'fallback_event_uuid': _snap_fallback,
			'npc_name': npc_name,
			'archetype_base': action.uuid,
			'outcome': _outcome,
		}
		EventManager.scan_events(0, context)
	
	PlayerState.last_action_tags = _identifying_tags.duplicate()
	Logging.info("MainActionButton: 非 sub-action 路径，更新 last_action_tags=%s" % str(PlayerState.last_action_tags))


## Sub-action Picker 回调 — 新架构下仅处理取消/空选择清理
## 实际执行由 NpcActionButton 触发 SubActionExecutor.execute()
func _on_sub_action_picked(entity) -> void:
	if entity == null:
		Logging.info("MainActionButton._on_sub_action_picked: entity is null（玩家拒绝回答），清理 VolatileState")
		_pop_auto_remote_override()
		VolatileState.action_state.clear()
		return
	var sub_uuid: String = entity.uuid if entity is GameEntity else ""
	if sub_uuid.is_empty():
		Logging.err("MainActionButton._on_sub_action_picked: entity.uuid is empty, aborting")
		_pop_auto_remote_override()
		VolatileState.action_state.clear()
		return
	
	Logging.info("MainActionButton._on_sub_action_picked: sub_uuid=%s entity_name=%s（NpcActionButton 已执行，仅清理 auto_remote_override）" % [sub_uuid, entity.name if entity else "NULL"])
	_pop_auto_remote_override()
	# 不在此处执行 — SubActionButton toggle + NpcActionButton 已完成全部流程


## PickerTapeAttachment CheckBox toggle 回调
func _on_picker_checkbox_toggled(toggled_on: bool) -> void:
	Logging.info("MainActionButton._on_picker_checkbox_toggled: toggled_on=%s" % str(toggled_on))


## 弹出上一次自动开启的 remote override
func _pop_auto_remote_override() -> void:
	if not VolatileState.action_state.did_auto_enable_remote:
		return
	VolatileState.action_state.did_auto_enable_remote = false
	RemoteActionFilterManager.pop_show_remote_override()
	Logging.info("MainActionButton._pop_auto_remote_override: 已恢复 show_remote snapshot")


## 🆕 判定 sub_action 是否为"特殊"行动。
## 规则（满足任一即特殊）：
##   1. cost archetype 中存在非 PropertyOperator 的 operator
##   2. aciton_requirements 中有 PoemRequirement（消耗诗词）
## 不满足任一 → 普通。
func _is_special_sub_action(sub_action: Action) -> bool:
	if not sub_action:
		return false

	# ── 条件 1: cost archetype 含非 PropertyOperator ──
	var cost_arch = Database.get_archetype_by_uuid(sub_action.uuid, "cost")
	if cost_arch != null and not cost_arch.operators.is_empty():
		for op in cost_arch.operators:
			if not op is PropertyOperator:
				Logging.info("MainActionButton._is_special_sub_action: '%s' cost archetype 含非 PropertyOperator (%s) → 特殊" % [sub_action.name, op.get_class() if op else "null"])
				return true

	# ── 条件 2: 含 PoemRequirement（消耗诗词算特殊资源）──
	if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
		for req in sub_action.aciton_requirements:
			if req is PoemRequirement:
				Logging.info("MainActionButton._is_special_sub_action: '%s' 含 PoemRequirement → 特殊" % sub_action.name)
				return true

	Logging.info("MainActionButton._is_special_sub_action: '%s' 无特殊条件 → 普通" % sub_action.name)
	return false
