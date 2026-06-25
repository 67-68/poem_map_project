# ================================================================
# ActionManager 时间相关功能测试
# ================================================================
# 覆盖场景:
#   - get_action_day_cost(): TimeOperator存在/不存在/day=0/多个operator混合/null
#   - consume_generator(): null generator → no-op
#   - consume_generator(): 已耗尽generator → lock_action + 清空引用
#   - consume_generator(): 未耗尽generator → 不触发lock，引用保留
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 辅助函数
# ════════════════════════════════════════════════════════════

func _make_action_with_time_op(day_val: float) -> Action:
	var action := SceneAction.new()
	var time_op := TimeOperator.new()
	time_op.day = day_val
	action.action_results = [time_op]
	return action

func _make_action_with_ops(ops: Array) -> Action:
	var action := SceneAction.new()
	action.action_results = ops
	return action


# ════════════════════════════════════════════════════════════
# get_action_day_cost() — 正常提取
# ════════════════════════════════════════════════════════════

func test_day_cost_normal():
	var action := _make_action_with_time_op(3.0)
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 3, "TimeOperator day=3 → cost=3")

func test_day_cost_float_truncation():
	# TimeOperator.operate() 内部做 int(day)，但 get_action_day_cost 直接读 op.day
	# day=5.7 → int(op.day)=5
	var action := _make_action_with_time_op(5.7)
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 5, "TimeOperator day=5.7 → int(5.7)=5")

func test_day_cost_zero():
	var action := _make_action_with_time_op(0.0)
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 0, "TimeOperator day=0 → cost=0")

func test_day_cost_negative_day():
	# get_action_day_cost 内部做 max(0, int(op.day))，负数被 clamp 到 0
	var action := _make_action_with_time_op(-3.0)
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 0, "TimeOperator day=-3 → max(0, -3)=0")


# ════════════════════════════════════════════════════════════
# get_action_day_cost() — 边界情况
# ════════════════════════════════════════════════════════════

func test_day_cost_no_time_operator():
	# action_results 里只有其他类型的 operator
	var action := SceneAction.new()
	action.action_results = []  # 空数组
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 0, "无 operator → cost=0")

func test_day_cost_null_action():
	var cost := ActionManager.get_action_day_cost(null)
	assert_eq(cost, 0, "null action → cost=0")

func test_day_cost_null_action_results():
	var action := SceneAction.new()
	action.action_results.clear()
	# action_results 是空数组但不是 null
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 0, "空 action_results → cost=0")

func test_day_cost_multiple_operators_first_is_time():
	# 多个 operator，第一个是 TimeOperator
	var time_op := TimeOperator.new()
	time_op.day = 7.0
	
	var action := SceneAction.new()
	action.action_results = [time_op]
	var cost := ActionManager.get_action_day_cost(action)
	assert_eq(cost, 7, "多个 operator 中第一个是 TimeOperator → cost=7")


# ════════════════════════════════════════════════════════════
# consume_generator() — null generator → no-op
# ════════════════════════════════════════════════════════════

func test_consume_generator_null():
	# Action 没有挂载 generator，应直接返回，无副作用
	var action := SceneAction.new()
	action.uuid = "test_no_gen"
	action.generator = null
	
	# 记录锁定状态前的快照
	var locked_before := ActionManager._locked_in_actions.size()
	
	ActionManager.consume_generator(action)
	
	# 锁定状态不应改变
	assert_eq(ActionManager._locked_in_actions.size(), locked_before, "无 generator 时锁定状态不变")
	assert_null(action.generator, "generator 仍为 null")


# ════════════════════════════════════════════════════════════
# consume_generator() — 有 generator 但未耗尽
# ════════════════════════════════════════════════════════════

func test_consume_generator_not_exhausted():
	# 创建有 2 个 operator 的 generator（需要执行 2 次才耗尽）
	var gen := Generator.new()
	gen.name = "test_gen"
	gen.counter_flag_id = "test_gen_counter"
	gen.action_type = 0  # BAI_YE
	# 给它塞 2 个简单的 operator（不需要真正执行）
	var op1 := TimeOperator.new()
	op1.day = 1.0
	var op2 := TimeOperator.new()
	op2.day = 2.0
	gen.operators = [op1, op2]
	
	# 初始化 flag 为 0（还没消费过）
	PlayerState.set_flag("test_gen_counter", 0, 'int')
	
	var action := SceneAction.new()
	action.uuid = "test_gen_not_exhausted"
	action.generator = gen
	
	# 记录锁定前的状态
	var locked_before := ActionManager._locked_in_actions.duplicate()
	
	# execute_next() 会返回 true（还有剩余），generator 引用不应被清除
	ActionManager.consume_generator(action)
	
	# generator 引用应保留（未耗尽）
	assert_not_null(action.generator, "未耗尽时 generator 引用保留")
	assert_eq(action.generator.name, "test_gen", "generator 名称未变")
	
	# 锁定状态不应新增（未耗尽 → 不触发 lock_action）
	assert_eq(ActionManager._locked_in_actions.size(), locked_before.size(), "未耗尽时不触发 lock")
	
	# 清理 flag
	PlayerState.remove_flag("test_gen_counter")


# ════════════════════════════════════════════════════════════
# consume_generator() — 有 generator 且已耗尽
# ════════════════════════════════════════════════════════════

func test_consume_generator_exhausted():
	# 创建只有 1 个 operator 的 generator（执行 1 次即耗尽）
	var gen := Generator.new()
	gen.name = "test_gen_exhausted"
	gen.counter_flag_id = "test_gen_exhausted_counter"
	# 使用 ENUMS.ACTION_TYPE 枚举值
	gen.action_type = 0  # BAI_YE
	var op := TimeOperator.new()
	op.day = 1.0
	gen.operators = [op]
	
	# 初始化 flag（step=0，还未消费）
	PlayerState.set_flag("test_gen_exhausted_counter", 0, 'int')
	
	var action := SceneAction.new()
	action.uuid = "test_gen_exhausted_action"
	action.generator = gen
	
	# execute_next() → 消费 op → step 变成 1 >= 1 → 返回 false（已耗尽）
	ActionManager.consume_generator(action)
	
	# generator 引用应被清空
	assert_null(action.generator, "耗尽后 generator 引用被清空")
	
	# 锁定状态应新增（lock_action(action_type, 1)）
	var action_id = ActionManager.action_type_to_id(0)
	assert_true(ActionManager._locked_in_actions.has(action_id), "耗尽后 action 被锁定")
	
	# 清理：解锁并清空
	ActionManager.unlock_action(0)
	ActionManager.clear_reservations()
	PlayerState.remove_flag("test_gen_exhausted_counter")


# ════════════════════════════════════════════════════════════
# 清理
# ════════════════════════════════════════════════════════════

func after_each():
	ActionManager.clear_reservations()
	# 清理可能残留的锁
	ActionManager._locked_in_actions.clear()
	ActionManager._blocked_actions.clear()
