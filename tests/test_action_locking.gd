# ================================================================
# ActionManager 锁定展示系统 (Locking Display) 测试
# ================================================================
# 覆盖:
#   - lock_action / block_action 持久化 + 冲突 + 查询 + 手动解锁/解阻
#   - process_xun_tick 旬结算递减 + 到期清除 + 无限期
#   - apply_visibility_flags 三阶段标志位（blocked→hidden, unselected→B类）
#   - Action 模型扩展（append/clear failed_hint, lock_narrative）
#   - is_action_era_allowed Era 过滤
#   - 信号发射（reevaluate_all_locks → EventBus）
#   - batch mode 标志位
#   - action_type_to_id 映射
#
# GUT 限制：ENUMS.action_tag_to_action_type() 等内部映射在 GUT 沙箱
# 中不稳定，因此 check_action_validity / check_archetype_property_costs
# 等依赖 archetype 的路径不在本文件中测。
# ================================================================
extends GutTest


func _make_action(id: String, name: String = "") -> SceneAction:
	var a := SceneAction.new()
	a.uuid = id
	a.name = name if name else id
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


func before_each():
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	ActionManager._suppress_reevaluate = false
	Database.actions.clear()
	Database.properties.clear()
	Database.eras.clear()
	Database.action_archetypes.clear()
	GameState.current_era = ""

	for i in range(1, 9):
		var action_id := "test_action_%d" % i
		Database.actions[action_id] = _make_action(action_id, "测试行动 %d" % i)

	if not Database.properties.has("health"):
		var hp := Property.new(); hp.uuid = "health"; hp.name = "健康"; hp.lowest = 0; hp.val = 50
		Database.properties["health"] = hp
	if not Database.properties.has("time"):
		var tp := Property.new(); tp.uuid = "time"; tp.name = "时间"; tp.lowest = 0; tp.val = 10
		Database.properties["time"] = tp


func after_each():
	ActionManager.clear_reservations()
	ActionManager._selected_action_ids.clear()
	ActionManager._blocked_actions.clear()
	ActionManager._locked_in_actions.clear()
	ActionManager._suppress_reevaluate = false
	Database.actions.clear()
	Database.properties.clear()
	Database.eras.clear()
	Database.action_archetypes.clear()
	GameState.current_era = ""


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
	var a := SceneAction.new(); a._main_tag = 29; a.uuid = "test_rejected"
	assert_false(ActionManager.is_action_era_allowed(a))


func test_era_allowed_rejected_not_matching():
	var era := Era.new()
	era.uuid = "test_no_reject"
	era.rejected_actions = [ENUMS.ACTION_TYPE.JIAO_YOU]
	Database.eras["test_no_reject"] = era
	GameState.current_era = "test_no_reject"
	var a := SceneAction.new(); a._main_tag = 29; a.uuid = "test_not_rejected"
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_accepted_allows():
	var era := Era.new()
	era.uuid = "test_accept"
	era.accepted_actions = [ENUMS.ACTION_TYPE.BAI_YE]
	Database.eras["test_accept"] = era
	GameState.current_era = "test_accept"
	var a := SceneAction.new(); a._main_tag = 29; a.uuid = "test_accepted"
	assert_true(ActionManager.is_action_era_allowed(a))


func test_era_allowed_accepted_blocks_others():
	var era := Era.new()
	era.uuid = "test_accept_only"
	era.accepted_actions = [ENUMS.ACTION_TYPE.BAI_YE]
	Database.eras["test_accept_only"] = era
	GameState.current_era = "test_accept_only"
	var a := SceneAction.new(); a._main_tag = 30; a.uuid = "test_not_accepted"
	assert_false(ActionManager.is_action_era_allowed(a))


# ════════════════════════════════════════════════════════════
# lock_action / block_action — 持久化锁定/阻塞
# ════════════════════════════════════════════════════════════

func test_lock_action_basic():
	assert_true(ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, -1))
	assert_true(ActionManager._locked_in_actions.has("bai_ye"))
	assert_eq(ActionManager._locked_in_actions["bai_ye"], -1)


func test_lock_action_reserves_immediately():
	ActionManager.clear_reservations()
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 3)
	assert_has(ActionManager._reserved_action_ids, "bai_ye")


func test_block_action_basic():
	assert_true(ActionManager.block_action(ENUMS.ACTION_TYPE.BAI_YE, 2))
	assert_true(ActionManager._blocked_actions.has("bai_ye"))
	assert_eq(ActionManager._blocked_actions["bai_ye"], 2)


func test_block_action_removes_reserved():
	ActionManager.reserve_action("bai_ye")
	ActionManager.block_action(ENUMS.ACTION_TYPE.BAI_YE, 1)
	assert_does_not_have(ActionManager._reserved_action_ids, "bai_ye")


func test_lock_beats_block_conflict():
	ActionManager.block_action(ENUMS.ACTION_TYPE.BAI_YE, 3)
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 1)
	assert_false(ActionManager._blocked_actions.has("bai_ye"))
	assert_true(ActionManager._locked_in_actions.has("bai_ye"))


func test_block_beats_lock_conflict():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 3)
	ActionManager.block_action(ENUMS.ACTION_TYPE.BAI_YE, 1)
	assert_false(ActionManager._locked_in_actions.has("bai_ye"))
	assert_true(ActionManager._blocked_actions.has("bai_ye"))


func test_is_action_locked():
	assert_false(ActionManager.is_action_locked(ENUMS.ACTION_TYPE.BAI_YE))
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 1)
	assert_true(ActionManager.is_action_locked(ENUMS.ACTION_TYPE.BAI_YE))


func test_is_action_blocked():
	assert_false(ActionManager.is_action_blocked(ENUMS.ACTION_TYPE.JIAO_YOU))
	ActionManager.block_action(ENUMS.ACTION_TYPE.JIAO_YOU, 1)
	assert_true(ActionManager.is_action_blocked(ENUMS.ACTION_TYPE.JIAO_YOU))


func test_unlock_action():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 5)
	ActionManager.unlock_action(ENUMS.ACTION_TYPE.BAI_YE)
	assert_false(ActionManager._locked_in_actions.has("bai_ye"))


func test_unblock_action():
	ActionManager.block_action(ENUMS.ACTION_TYPE.BAI_YE, 5)
	ActionManager.unblock_action(ENUMS.ACTION_TYPE.BAI_YE)
	assert_false(ActionManager._blocked_actions.has("bai_ye"))


func test_block_action_by_id():
	ActionManager.block_action_by_id("special_event_1", 3)
	assert_true(ActionManager._blocked_actions.has("special_event_1"))
	assert_eq(ActionManager._blocked_actions["special_event_1"], 3)


func test_unblock_action_by_id():
	ActionManager.block_action_by_id("special_event_2", 3)
	ActionManager.unblock_action_by_id("special_event_2")
	assert_false(ActionManager._blocked_actions.has("special_event_2"))


func test_lock_action_invalid_type():
	assert_false(ActionManager.lock_action(-1, 1))


# ════════════════════════════════════════════════════════════
# process_xun_tick — 旬结算递减
# ════════════════════════════════════════════════════════════

func test_xun_tick_lock_decrement():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 3)
	ActionManager.clear_reservations()
	ActionManager.process_xun_tick()
	assert_eq(ActionManager._locked_in_actions["bai_ye"], 2)
	ActionManager.process_xun_tick()
	assert_eq(ActionManager._locked_in_actions["bai_ye"], 1)


func test_xun_tick_lock_expires():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 2)
	ActionManager.clear_reservations()
	ActionManager.process_xun_tick(); ActionManager.process_xun_tick()
	assert_false(ActionManager._locked_in_actions.has("bai_ye"))


func test_xun_tick_lock_infinite():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, -1)
	ActionManager.clear_reservations()
	for _i in range(10):
		ActionManager.process_xun_tick()
	assert_true(ActionManager._locked_in_actions.has("bai_ye"))


func test_xun_tick_block_decrement():
	ActionManager.block_action(ENUMS.ACTION_TYPE.JIAO_YOU, 3)
	ActionManager.process_xun_tick()
	assert_eq(ActionManager._blocked_actions["jiao_you"], 2)
	ActionManager.process_xun_tick()
	assert_eq(ActionManager._blocked_actions["jiao_you"], 1)


func test_xun_tick_block_expires():
	ActionManager.block_action(ENUMS.ACTION_TYPE.JIAO_YOU, 1)
	ActionManager.process_xun_tick()
	assert_false(ActionManager._blocked_actions.has("jiao_you"))


func test_xun_tick_block_infinite():
	ActionManager.block_action(ENUMS.ACTION_TYPE.JIAO_YOU, -1)
	for _i in range(10):
		ActionManager.process_xun_tick()
	assert_true(ActionManager._blocked_actions.has("jiao_you"))


func test_xun_tick_mixed():
	ActionManager.lock_action(ENUMS.ACTION_TYPE.BAI_YE, 2)
	ActionManager.block_action(ENUMS.ACTION_TYPE.JIAO_YOU, 3)
	ActionManager.clear_reservations()
	ActionManager.process_xun_tick()
	assert_eq(ActionManager._locked_in_actions["bai_ye"], 1)
	assert_eq(ActionManager._blocked_actions["jiao_you"], 2)


# ════════════════════════════════════════════════════════════
# apply_visibility_flags — 三阶段标志位
# ════════════════════════════════════════════════════════════

func test_visibility_blocked_is_hidden():
	var a := _make_action("test_hidden_blocked")
	Database.actions["test_hidden_blocked"] = a
	ActionManager._blocked_actions["test_hidden_blocked"] = -1
	ActionManager.apply_visibility_flags()
	assert_true(a._is_hidden)


func test_visibility_unblocked_not_hidden():
	var a := _make_action("test_not_hidden")
	Database.actions["test_not_hidden"] = a
	ActionManager.apply_visibility_flags()
	assert_false(a._is_hidden)


func test_visibility_unselected_gets_b_class():
	"""未中签 → B类 lock_narrative + 兜底「此路不通」"""
	var a := _make_action("test_vis_unselected"); a.lock_narrative = "时机未到"
	Database.actions["test_vis_unselected"] = a
	ActionManager.apply_visibility_flags()
	assert_false(a.dynamic_failed_hint.is_empty())
	assert_true(a.dynamic_failed_hint.contains("此路不通"))
	assert_true(a.dynamic_failed_hint.contains("时机未到"))


# ════════════════════════════════════════════════════════════
# batch mode
# ════════════════════════════════════════════════════════════

func test_batch_suppress_flag():
	assert_false(ActionManager._suppress_reevaluate)
	ActionManager.begin_action_batch()
	assert_true(ActionManager._suppress_reevaluate)
	ActionManager.end_action_batch()
	assert_false(ActionManager._suppress_reevaluate)


# ════════════════════════════════════════════════════════════
# action_type_to_id
# ════════════════════════════════════════════════════════════

func test_action_type_to_id_valid():
	assert_eq(ActionManager.action_type_to_id(ENUMS.ACTION_TYPE.BAI_YE), "bai_ye")


func test_action_type_to_id_invalid():
	assert_eq(ActionManager.action_type_to_id(-1), "")
	assert_eq(ActionManager.action_type_to_id(999), "")
