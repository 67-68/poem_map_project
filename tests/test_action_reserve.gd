# ================================================================
# ActionManager 预定机制 (Reserve) 测试
# ================================================================
# 覆盖场景：
#   - 基本预定 + 抽取
#   - 6 个席位全满
#   - 重复预定
#   - 预定不在可用池中
#   - 预定数量超过可用池大小
#   - 自动清空 (跨回合污染防护)
#   - 无预定时的正常随机抽取
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 清理 ActionManager 的预定状态
	ActionManager.clear_reservations()
	
	# 创建 8 个 mock SceneAction 注入 Database.actions
	# 用 8 个保证池子够大，不会干扰随机抽取
	Database.actions.clear()
	for i in range(1, 9):
		var action_id = "test_action_%d" % i
		var action = SceneAction.new()
		action.uuid = action_id
		action.name = "测试行动 %d" % i
		Database.actions[action_id] = action


func after_each():
	# 清理，不影响其他测试
	ActionManager.clear_reservations()
	Database.actions.clear()


# ════════════════════════════════════════════════════════════
# 辅助函数
# ════════════════════════════════════════════════════════════

## 模拟 get_available_scene_actions 的返回值格式：
## {action_id: weight_count} — 每个 action 算 1 个权重
## 用 untyped Array 避免 Godot 4 typed array 传参的 covariance 问题
func _make_action_pool(action_ids: Array) -> Dictionary:
	var pool = {}
	for id in action_ids:
		pool[id] = 1
	return pool


# ════════════════════════════════════════════════════════════
# 基本预定
# ════════════════════════════════════════════════════════════

func test_reserve_basic():
	"""预定 1 个 action，它应出现在最终选中列表里"""
	# Arrange
	var ok = ActionManager.reserve_action("test_action_1")
	assert_true(ok, "预定应成功")
	
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	
	# Act
	var selected = ActionManager.pick_top_actions(pool)
	
	# Assert: test_action_1 必须在选中列表中
	var uuids = selected.map(func(a): return a.uuid)
	assert_has(uuids, "test_action_1", "预定的 action 应被选中")
	assert_eq(selected.size(), 6, "应返回 6 个 action")


func test_reserve_multiple():
	"""预定 3 个 action，它们都应出现在最终列表里"""
	# Arrange
	for id_ in ["test_action_1", "test_action_3", "test_action_5"]:
		assert_true(ActionManager.reserve_action(id_), "预定 %s 应成功" % id_)
	
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	
	# Act
	var selected = ActionManager.pick_top_actions(pool)
	
	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	assert_has(uuids, "test_action_1", "预定 action_1 应被选中")
	assert_has(uuids, "test_action_3", "预定 action_3 应被选中")
	assert_has(uuids, "test_action_5", "预定 action_5 应被选中")
	assert_eq(selected.size(), 6, "应返回 6 个 action")


# ════════════════════════════════════════════════════════════
# 6 个席位全满
# ════════════════════════════════════════════════════════════

func test_reserve_all_six_slots():
	"""预定满 6 个席位，全部应被选中"""
	# Arrange
	var ids = [
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	]
	for id_ in ids:
		assert_true(ActionManager.reserve_action(id_), "预定 %s 应成功" % id_)
	
	# 直接传 literal 避免 typed array 传参问题
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	
	# Act
	var selected = ActionManager.pick_top_actions(pool)
	
	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	for id_ in ids:
		assert_has(uuids, id_, "预定的 %s 应被选中" % id_)
	assert_eq(selected.size(), 6, "应返回 6 个 action")


func test_reserve_overflow():
	"""第 7 个预定应失败（席位已满）"""
	# Arrange: 满 6 个
	for i in range(1, 7):
		var id_ = "test_action_%d" % i
		assert_true(ActionManager.reserve_action(id_), "第 %d 个预定应成功" % i)
	
	# Act — 第 7 个 → 触发 push_error
	var ok = ActionManager.reserve_action("test_action_7")
	
	# Assert
	assert_false(ok, "第 7 个预定应失败")
	assert_push_error(1, "预留席位已满")


# ════════════════════════════════════════════════════════════
# 重复预定
# ════════════════════════════════════════════════════════════

func test_reserve_duplicate():
	"""重复预定同一个 action 应失败"""
	# Arrange
	assert_true(ActionManager.reserve_action("test_action_1"), "首次预定应成功")
	
	# Act — 重复 → 触发 push_error
	var ok = ActionManager.reserve_action("test_action_1")
	
	# Assert
	assert_false(ok, "重复预定应失败")
	assert_push_error(1, "重复预定")


# ════════════════════════════════════════════════════════════
# 预定不在可用池中
# ════════════════════════════════════════════════════════════

func test_reserve_not_in_pool():
	"""预定的 action 不在可用池中，应报错并跳过该预定"""
	# Arrange
	assert_true(ActionManager.reserve_action("test_action_1"), "预定应成功")
	assert_true(ActionManager.reserve_action("nonexistent_action"), "预定应成功（只检查容量，不检查存在性）")
	
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	
	# Act — pick_top_actions 中触发 push_error（nonexistent_action 不在池中）
	var selected = ActionManager.pick_top_actions(pool)
	
	# Assert
	var uuids = selected.map(func(a): return a.uuid)
	assert_has(uuids, "test_action_1", "有效的预定 action 应被选中")
	assert_does_not_have(uuids, "nonexistent_action", "不存在的 action 不应被选中")
	assert_eq(selected.size(), 6, "应返回 6 个 action")
	assert_push_error(1, "不在当前可用池")


# ════════════════════════════════════════════════════════════
# 预留数量超过可用池大小
# ════════════════════════════════════════════════════════════

func test_reserve_more_than_pool():
	"""预订数量超过可用池大小时，应报错并返回空数组"""
	# Arrange: 池子里只有 3 个 action
	# 预定了 4 个（超过 3）
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3"
	])
	assert_true(ActionManager.reserve_action("test_action_1"), "预定应成功")
	assert_true(ActionManager.reserve_action("test_action_2"), "预定应成功")
	assert_true(ActionManager.reserve_action("test_action_3"), "预定应成功")
	assert_true(ActionManager.reserve_action("test_action_4"), "预定应成功")  # 这个不在池中
	
	# Act — pick_top_actions 触发 push_error（4 个预定 > 3 个可用）
	var selected = ActionManager.pick_top_actions(pool)
	
	# Assert
	assert_eq(selected.size(), 0, "预留超过可用池时，应返回空数组")
	assert_push_error(1, "超过当前可用行动数量")


# ════════════════════════════════════════════════════════════
# 自动清空
# ════════════════════════════════════════════════════════════

func test_reserve_auto_cleared():
	"""pick_top_actions 后，预定应被自动清空"""
	# Arrange
	assert_true(ActionManager.reserve_action("test_action_1"), "预定应成功")
	
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6"
	])
	
	# Act
	ActionManager.pick_top_actions(pool)
	
	# Assert: 再次预定同一个 action 应成功（说明已被清空）
	var ok = ActionManager.reserve_action("test_action_1")
	assert_true(ok, "抽取后预定应成功（表示自动清空）")


func test_reserve_auto_cleared_on_error():
	"""即使 pick_top_actions 报错，预定也应被清空"""
	# Arrange: 3 个预定 > 2 个可用 → 触发 error
	var pool = _make_action_pool(["test_action_1", "test_action_2"])
	assert_true(ActionManager.reserve_action("test_action_1"), "预定应成功")
	assert_true(ActionManager.reserve_action("test_action_2"), "预定应成功")
	assert_true(ActionManager.reserve_action("test_action_3"), "预定应成功")
	
	# Act — 触发 push_error
	ActionManager.pick_top_actions(pool)
	
	# Assert: 现在可以预定新的（说明已清空）
	var ok = ActionManager.reserve_action("test_action_4")
	assert_push_error(1, "超过当前可用行动数量")
	assert_true(ok, "报错后也能清空预定")


# ════════════════════════════════════════════════════════════
# 无预定正常行为
# ════════════════════════════════════════════════════════════

func test_no_reserve_normal():
	"""无预定时，正常抽取 6 个 action"""
	var pool = _make_action_pool([
		"test_action_1", "test_action_2", "test_action_3",
		"test_action_4", "test_action_5", "test_action_6",
		"test_action_7", "test_action_8"
	])
	
	var selected = ActionManager.pick_top_actions(pool)
	
	assert_eq(selected.size(), 6, "无预定时应返回 6 个")
	# 全部应从池中来
	for a in selected:
		assert_true(pool.has(a.uuid), "选中的 action 应在池中: %s" % a.uuid)


func test_no_reserve_less_than_six():
	"""可用 action 少于 6 个时，应返回所有可用"""
	var pool = _make_action_pool(["test_action_1", "test_action_2", "test_action_3"])
	
	var selected = ActionManager.pick_top_actions(pool)
	
	assert_eq(selected.size(), 3, "池子只有 3 个时，应返回 3 个")
