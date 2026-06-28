# ================================================================
# ActionManager 锁定展示系统 (Locking Display) 测试
# ================================================================
# 覆盖场景：
#   - check_action_validity() 纯函数
#   - pick_top_actions() 中签/未中签追踪
#   - reevaluate_all_locks() 属性变动重评估
#   - is_action_era_allowed() Era 过滤
#   - Action 模型扩展
# ================================================================
extends GutTest


func _make_action(id: String, name: String = "") -> SceneAction:
	var a := SceneAction.new()
	a.uuid = id
	a.name = name if name else id
	return a


func _make_action_with_prop_req(id: String, prop: String, val: int, op: int) -> SceneAction:
	var a := _make_action(id)
	var req := PropertyRequirement.new()
	req.property = prop
	req.value = val
	req.operator = op
	a.aciton_requirements = [req]
	return a


func _make_action_with_time_cost(id: String, day_cost: float) -> SceneAction:
	var a := _make_action(id)
	var time_op := TimeOperator.new()
	time_op.day = day_cost
	a.action_results = [time_op]
	return a


func _make_action_with_narrative(id: String, narrative: String) -> SceneAction:
	var a := _make_action(id)
	a.lock_narrative = narrative
	return a


func _make_action_pool(action_ids: Array) -> Dictionary:
	var pool = {}
	for id in action_ids:
		pool[id] = 1
	return pool


func _setup_mock_properties() -> void:
	if not Database.properties.has("health"):
		var health_prop := Property.new()
		health_prop.uuid = "health"
		health_prop.name = "健康"
		health_prop.val = 50
		Database.properties["health"] = health_prop
	if not Database.properties.has("time"):
		var time_prop := Property.new()
		time_prop.uuid = "time"
		time_prop.name = "时间"
		time_prop.val = 10
		Database.properties["time"] = time_prop


func before_each():
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	Database.actions.clear()
	Database.properties.clear()
	Database.eras.clear()
	GameState.current_era = ""
	
	for i in range(1, 9):
		var action_id := "test_action_%d" % i
		Database.actions[action_id] = _make_action(action_id, "测试行动 %d" % i)
	_setup_mock_properties()


func after_each():
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	Database.actions.clear()
	Database.properties.clear()
	Database.eras.clear()
	GameState.current_era = ""


# ════════════════════════════════════════════════════════════
# check_action_validity
# ════════════════════════════════════════════════════════════

func test_validity_no_requirements():
	var a := _make_action("test_no_req")
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "无需求时应返回 valid")
	assert_eq(result.reasons.size(), 0, "无需求时 reasons 应为空")


func test_validity_requirements_met():
	Database.properties["health"].val = 80
	var a := _make_action_with_prop_req("test_req_met", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "health=80 > 50 时应返回 valid")
	assert_eq(result.reasons.size(), 0)


func test_validity_requirements_not_met():
	var a := _make_action_with_prop_req("test_req_fail", "health", 80, REQ_OPERATOR.COMPARE.GREATER_THAN)
	var result := ActionManager.check_action_validity(a)
	assert_false(result.valid, "health=50 < 80 时应返回 invalid")
	assert_gt(result.reasons.size(), 0, "应包含失败原因")


func test_validity_time_insufficient():
	Database.properties["time"].val = 3
	var a := _make_action_with_time_cost("test_time_short", 5.0)
	var result := ActionManager.check_action_validity(a)
	assert_false(result.valid, "time=3 < 5 时应返回 invalid")
	assert_gt(result.reasons.size(), 0, "应包含时间不足原因")


func test_validity_time_sufficient():
	Database.properties["time"].val = 10
	var a := _make_action_with_time_cost("test_time_enough", 5.0)
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "time=10 >= 5 时应返回 valid")


func test_validity_no_time_cost():
	Database.properties["time"].val = 0
	var a := _make_action("test_no_time_cost")
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "无时间消耗时始终 valid")


func test_validity_negative_time_cost():
	var a := _make_action_with_time_cost("test_neg_time", -3.0)
	var result := ActionManager.check_action_validity(a)
	assert_true(result.valid, "负数 day 被 clamp 为 0 → valid")


# ════════════════════════════════════════════════════════════
# pick_top_actions
# ════════════════════════════════════════════════════════════

func test_pick_tracks_selected_ids():
	var pool := _make_action_pool(["test_action_1","test_action_2","test_action_3","test_action_4","test_action_5","test_action_6"])
	var selected := ActionManager.pick_top_actions(pool)
	assert_eq(ActionManager._selected_action_ids.size(), 6)
	for sa in selected:
		assert_true(ActionManager._selected_action_ids.has(sa.uuid))


func test_pick_clears_old_selected():
	ActionManager._selected_action_ids["stale_id"] = true
	var pool := _make_action_pool(["test_action_1","test_action_2","test_action_3","test_action_4","test_action_5","test_action_6"])
	ActionManager.pick_top_actions(pool)
	assert_does_not_have(ActionManager._selected_action_ids, "stale_id")


func test_pick_clears_failed_hints():
	var action_extra := _make_action("test_extra")
	action_extra.append_failed_hint("旧数据")
	Database.actions["test_extra"] = action_extra
	var pool := _make_action_pool(["test_action_1","test_action_2","test_action_3","test_action_4","test_action_5","test_action_6"])
	ActionManager.pick_top_actions(pool)
	assert_true(action_extra.dynamic_failed_hint.is_empty())


func test_pick_locks_unselected_with_narrative():
	Database.actions.clear()
	for i in range(1, 9):
		Database.actions["test_action_%d" % i] = _make_action_with_narrative("test_action_%d" % i, "理由%d" % i if i > 6 else "")
	var pool := _make_action_pool(["test_action_1","test_action_2","test_action_3","test_action_4","test_action_5","test_action_6","test_action_7","test_action_8"])
	ActionManager.pick_top_actions(pool)
	var locked := 0
	for i in range(7, 9):
		if not Database.actions["test_action_%d" % i].dynamic_failed_hint.is_empty():
			locked += 1
	assert_gt(locked, 0)


# ════════════════════════════════════════════════════════════
# reevaluate_all_locks
# ════════════════════════════════════════════════════════════

func test_reeval_selected_valid_unlocked():
	Database.properties["health"].val = 80
	var a := _make_action_with_prop_req("test_selected_ok", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_selected_ok"] = a
	ActionManager._selected_action_ids["test_selected_ok"] = true
	ActionManager.reevaluate_all_locks()
	assert_true(a.dynamic_failed_hint.is_empty())


func test_reeval_selected_invalid_locked():
	Database.properties["health"].val = 20
	var a := _make_action_with_prop_req("test_selected_fail", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_selected_fail"] = a
	ActionManager._selected_action_ids["test_selected_fail"] = true
	ActionManager.reevaluate_all_locks()
	assert_false(a.dynamic_failed_hint.is_empty())


func test_reeval_unselected_always_locked():
	Database.properties["health"].val = 80
	var a := _make_action_with_prop_req("test_unselected", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	a.lock_narrative = "今日不宜出行"
	Database.actions["test_unselected"] = a
	ActionManager.reevaluate_all_locks()
	assert_false(a.dynamic_failed_hint.is_empty())
	assert_true(a.dynamic_failed_hint.contains("今日不宜出行"))


func test_reeval_unselected_with_a_reason():
	Database.properties["health"].val = 20
	var a := _make_action_with_prop_req("test_unselected_a", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	a.lock_narrative = "未中签"
	Database.actions["test_unselected_a"] = a
	ActionManager.reevaluate_all_locks()
	assert_false(a.dynamic_failed_hint.is_empty())
	assert_true(a.dynamic_failed_hint.contains("未中签"))


# ════════════════════════════════════════════════════════════
# Action 模型扩展
# ════════════════════════════════════════════════════════════

func test_action_append_failed_hint():
	var a := _make_action("test_append")
	a.append_failed_hint("第一条原因")
	assert_eq(a.dynamic_failed_hint, "第一条原因")


func test_action_append_multiple():
	var a := _make_action("test_append_multi")
	a.append_failed_hint("原因A")
	a.append_failed_hint("原因B")
	assert_eq(a.dynamic_failed_hint, "原因A\n原因B")


func test_action_clear_failed_hint():
	var a := _make_action("test_clear")
	a.append_failed_hint("临时数据")
	a.clear_failed_hint()
	assert_true(a.dynamic_failed_hint.is_empty())


func test_action_append_empty_ignored():
	var a := _make_action("test_append_empty")
	a.append_failed_hint("")
	assert_true(a.dynamic_failed_hint.is_empty())
	a.append_failed_hint("实际内容")
	a.append_failed_hint("")
	assert_eq(a.dynamic_failed_hint, "实际内容")


func test_action_lock_narrative_export():
	var a := _make_action("test_lock_narrative")
	a.lock_narrative = "自定义叙事文本"
	assert_eq(a.lock_narrative, "自定义叙事文本")


# ════════════════════════════════════════════════════════════
# is_action_era_allowed
# ════════════════════════════════════════════════════════════

func test_era_allowed_no_era_set():
	var a := _make_action("test_era_empty")
	GameState.current_era = ""
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_no_era_resource():
	var a := _make_action("test_era_no_res")
	GameState.current_era = "non_existent_era"
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_rejected_blocks():
	var era := Era.new()
	era.uuid = "test_era_reject"
	era.rejected_actions = [ENUMS.ACTION_TYPE.BAI_YE]
	Database.eras["test_era_reject"] = era
	GameState.current_era = "test_era_reject"
	var a := SceneAction.new()
	a._main_tag = 29
	a.uuid = "test_rejected"
	assert_false(ActionManager.is_action_era_allowed(a))


func test_era_allowed_rejected_not_matching():
	var era := Era.new()
	era.uuid = "test_no_reject"
	era.rejected_actions = [ENUMS.ACTION_TYPE.JIAO_YOU]
	Database.eras["test_no_reject"] = era
	GameState.current_era = "test_no_reject"
	var a := SceneAction.new()
	a._main_tag = 29
	a.uuid = "test_not_rejected"
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_accepted_allows():
	var era := Era.new()
	era.uuid = "test_accept"
	era.accepted_actions = [ENUMS.ACTION_TYPE.BAI_YE]
	Database.eras["test_accept"] = era
	GameState.current_era = "test_accept"
	var a := SceneAction.new()
	a._main_tag = 29
	a.uuid = "test_accepted"
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_accepted_blocks_others():
	var era := Era.new()
	era.uuid = "test_accept_only"
	era.accepted_actions = [ENUMS.ACTION_TYPE.BAI_YE]
	Database.eras["test_accept_only"] = era
	GameState.current_era = "test_accept_only"
	var a := SceneAction.new()
	a._main_tag = 30
	a.uuid = "test_not_accepted"
	assert_false(ActionManager.is_action_era_allowed(a))


# ════════════════════════════════════════════════════════════
# 信号发射
# ════════════════════════════════════════════════════════════

func test_reeval_emits_refresh_signal():
	Database.properties["health"].val = 10
	var a := _make_action_with_prop_req("test_signal", "health", 50, REQ_OPERATOR.COMPARE.GREATER_THAN)
	Database.actions["test_signal"] = a
	ActionManager._selected_action_ids["test_signal"] = true
	watch_signals(EventBus)
	ActionManager.reevaluate_all_locks()
	assert_signal_emitted(EventBus, "request_refresh_action_locks")
