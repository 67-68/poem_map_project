# ================================================================
# ReserveActionOperator 测试
# ================================================================
# 覆盖场景：
#   - 基本预留（1 个 action 出现在最终列表）
#   - 预留多个 action
#   - 预留满 6 个席位
#   - 预留超过 6 个（触发 push_error）
#   - 预留空列表（无操作）
#   - 预留后 UI 刷新信号
#   - 预留 + 跨回合自动清空
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	ActionManager.clear_reservations()
	Database.actions.clear()
	for i in range(1, 9):
		var action_id = "test_action_%d" % i
		var action = SceneAction.new()
		action.uuid = action_id
		action.name = "测试行动 %d" % i
		Database.actions[action_id] = action


func after_each():
	ActionManager.clear_reservations()
	Database.actions.clear()


# ════════════════════════════════════════════════════════════
# 辅助函数
# ════════════════════════════════════════════════════════════

func _make_action_pool(action_ids: Array) -> Dictionary:
	var pool = {}
	for id in action_ids:
		pool[id] = 1
	return pool


# ════════════════════════════════════════════════════════════
# 基本预留
# ════════════════════════════════════════════════════════════

func test_reserve_single_action():
	"""ReserveActionOperator 预留 1 个 action，应出现在最终列表"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = ["test_action_1"]

	# Act
	op.operate()

	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	var selected = ActionManager.pick_top_actions(pool)

	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	assert_has(uuids, "test_action_1", "预留的 action 应被选中")
	assert_eq(selected.size(), 6, "应返回 6 个 action")


func test_reserve_multiple_actions():
	"""ReserveActionOperator 预留 3 个 action，都应出现在最终列表"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = ["test_action_1", "test_action_3", "test_action_5"]

	# Act
	op.operate()

	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	var selected = ActionManager.pick_top_actions(pool)

	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	assert_has(uuids, "test_action_1", "预留 action_1 应被选中")
	assert_has(uuids, "test_action_3", "预留 action_3 应被选中")
	assert_has(uuids, "test_action_5", "预留 action_5 应被选中")
	assert_eq(selected.size(), 6, "应返回 6 个 action")


# ════════════════════════════════════════════════════════════
# 席位满载
# ════════════════════════════════════════════════════════════

func test_reserve_all_six_slots():
	"""预留满 6 个席位，全部应被选中"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = [
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	]

	# Act
	op.operate()

	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	var selected = ActionManager.pick_top_actions(pool)

	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	for id in op.action_ids:
		assert_has(uuids, id, "预定的 %s 应被选中" % id)
	assert_eq(selected.size(), 6, "应返回 6 个 action")


func test_reserve_overflow():
	"""预留超过 6 个应触发 push_error，超出的失败"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = [
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6",
		"test_action_7"  # 第 7 个
	]

	# Act
	op.operate()

	# Assert: 第 7 个触发 push_error
	assert_push_error(1, "预留席位已满")


# ════════════════════════════════════════════════════════════
# 空列表 & 边界
# ════════════════════════════════════════════════════════════

func test_reserve_empty_list():
	"""action_ids 为空时，operator 应无操作"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = []

	# Act
	op.operate()

	# Assert: 正常抽取 6 个（无预留干扰）
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6",
		"test_action_7", "test_action_8"
	])
	var selected = ActionManager.pick_top_actions(pool)
	assert_eq(selected.size(), 6, "空预留时正常抽取 6 个")


# ════════════════════════════════════════════════════════════
# 跨回合自动清空（无持久状态）
# ════════════════════════════════════════════════════════════

func test_reserve_not_persistent():
	"""ReserveActionOperator 预留 + pick 后，下回合不应再受影响"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = ["test_action_1"]
	op.operate()

	# Act: 模拟一回合
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	ActionManager.pick_top_actions(pool)

	# Assert: 下回合可以再次预留 test_action_1（说明已清空）
	var ok = ActionManager.reserve_action("test_action_1")
	assert_true(ok, "抽取后可以再次预留，说明 operator 无持久状态")


# ════════════════════════════════════════════════════════════
# UI 刷新信号
# ════════════════════════════════════════════════════════════

func test_reserve_triggers_refresh_signal():
	"""ReserveActionOperator.operate() 应发射 request_refresh_action_panel"""
	# Arrange
	var op = ReserveActionOperator.new()
	op.action_ids = ["test_action_1"]

	# 使用 watch_signals 监控 EventBus
	watch_signals(EventBus)

	# Act
	op.operate()

	# Assert
	assert_signal_emitted(EventBus, "request_refresh_action_panel",
		"预留后应发射 request_refresh_action_panel 信号")
