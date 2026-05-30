# ================================================================
# Operator & Requirement 运行时执行测试
# ================================================================
# 架构师留言：
# 现有测试只覆盖了 DSL 解析层（parse_operator / parse_requirement），
# 没有任何一行代码调用过 .operate() 或 .compare()。
# 这个文件补上运行时执行测试。
#
# 优先级：P0（高风险低覆盖）
#   - TempFlagOperator: 反向清理逻辑，70行，4个type分支+reduce_if_above条件
#   - FlagRequirement: 空值兜底、多格式bool解析、4种比较操作符
# ================================================================
extends GutTest


# ════════════════════════════════════════════════════════════
# 测试生命周期
# ════════════════════════════════════════════════════════════

func before_each():
	# 清理 PlayerState 的 flag 状态和清理队列，保证每个测试独立
	PlayerState.flags.clear()
	PlayerState.session_deferred_cleanups.clear()
	# 确保 Database.flags 中有 test_flag 的类型定义
	# 在测试环境中数据库没有加载 flag 注册表，append_flag 依赖此校验
	if not Database.flags.has("test_flag"):
		var flag_def = Flag.new()
		flag_def.type = "int"
		Database.flags["test_flag"] = flag_def


# ════════════════════════════════════════════════════════════
# P0: TempFlagOperator — bool/set 分支
# ════════════════════════════════════════════════════════════

func test_tempflag_bool_set_with_prior_value():
	"""bool/set: 操作前 flag 存在且为 true -> 清理后恢复为 true"""
	# Arrange: 预设 flag 存在
	PlayerState.flags["test_flag"] = true
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "bool"
	op.operation = "set"
	op.value = false  # 设置为 false

	# Act: 执行
	op.operate()

	# Assert: 操作后 flag 变为 false
	assert_false(PlayerState.has_flag("test_flag"), "操作后 flag 应不存在（false 值被 erase）")

	# Assert: 清理算子已注册
	assert_eq(PlayerState.session_deferred_cleanups.size(), 1, "应注册 1 个清理算子")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_true(cleanup is FlagOperator, "清理算子应为 FlagOperator")
	assert_eq(cleanup.flag_id, "test_flag", "清理算子 flag_id 正确")
	assert_eq(cleanup.type, "bool", "清理算子 type 应为 bool")
	assert_eq(cleanup.operation, "set", "清理算子 operation 应为 set")
	assert_eq(cleanup.value, true, "清理算子 value 应为 true（恢复旧值）")

	# Assert: flush 后恢复
	PlayerState.flush_cleanups()
	assert_true(PlayerState.get_flag("test_flag"), "flush 后 flag 应恢复为 true")


func test_tempflag_bool_set_without_prior_value():
	"""bool/set: 操作前 flag 不存在 -> 清理后移除"""
	# Arrange: flag 不存在
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "bool"
	op.operation = "set"
	op.value = true  # 设置为 true

	# Act
	op.operate()

	# Assert: 操作后 flag 为 true
	assert_true(PlayerState.get_flag("test_flag"), "操作后 flag 应为 true")

	# Assert: 清理算子的 value 为 false（反向操作）
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.value, false, "无旧值时应设为 false 以触发移除")

	# Assert: flush 后 flag 被移除
	PlayerState.flush_cleanups()
	assert_false(PlayerState.has_flag("test_flag"), "flush 后 flag 应被移除")


# ════════════════════════════════════════════════════════════
# P0: TempFlagOperator — str/set 分支
# ════════════════════════════════════════════════════════════

func test_tempflag_str_set_with_prior_value():
	"""str/set: 操作前 flag 存在 -> flush 后恢复旧值"""
	PlayerState.flags["test_flag"] = "hello"
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "str"
	op.operation = "set"
	op.value = "world"

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), "world", "操作后 flag 应为 world")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.value, "hello", "清理算子 value 应为 hello")

	PlayerState.flush_cleanups()
	assert_eq(PlayerState.get_flag("test_flag"), "hello", "flush 后 flag 应恢复为 hello")


func test_tempflag_str_set_without_prior_value():
	"""str/set: 操作前 flag 不存在 -> flush 后移除"""
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "str"
	op.operation = "set"
	op.value = "temp"

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), "temp", "操作后 flag 应为 temp")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.value, "", "无旧值时应设为 '' 以触发移除")

	PlayerState.flush_cleanups()
	assert_false(PlayerState.has_flag("test_flag"), "flush 后 flag 应被移除")


# ════════════════════════════════════════════════════════════
# P0: TempFlagOperator — int/set 分支
# ════════════════════════════════════════════════════════════

func test_tempflag_int_set_with_prior_value():
	"""int/set: 操作前 flag 存在 -> flush 后恢复旧值"""
	PlayerState.flags["test_flag"] = 100
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "set"
	op.value = 50

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 50, "操作后 flag 应为 50")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.value, 100, "清理算子 value 应为 100")

	PlayerState.flush_cleanups()
	assert_eq(PlayerState.get_flag("test_flag"), 100, "flush 后 flag 应恢复为 100")


func test_tempflag_int_set_without_prior_value():
	"""int/set: 操作前 flag 不存在 -> flush 后移除"""
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "set"
	op.value = 30

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 30, "操作后 flag 应为 30")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.value, 0, "无旧值时应设为 0 以触发移除")

	PlayerState.flush_cleanups()
	assert_false(PlayerState.has_flag("test_flag"), "flush 后 flag 应被移除")


# ════════════════════════════════════════════════════════════
# P0: TempFlagOperator — int/append 分支
# ════════════════════════════════════════════════════════════

func test_tempflag_int_append_with_prior():
	"""int/append: 操作前 flag 存在 -> flush 后恢复旧值"""
	PlayerState.flags["test_flag"] = 10
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "append"
	op.value = 5

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 15, "操作后 flag 应为 15")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.operation, "append", "清理算子 operation 应为 append")
	assert_eq(cleanup.value, -5, "清理算子 value 应为 -5（对冲）")

	PlayerState.flush_cleanups()
	assert_eq(PlayerState.get_flag("test_flag"), 10, "flush 后 flag 应恢复为 10")


func test_tempflag_int_append_no_prior():
	"""int/append: 操作前 flag 不存在 -> flush 后恢复 0（移除）"""
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "append"
	op.value = 5

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 5, "操作后 flag 应为 5")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.operation, "append", "清理算子 operation 应为 append")
	assert_eq(cleanup.value, -5, "清理算子 value 应为 -5")

	PlayerState.flush_cleanups()
	assert_false(PlayerState.has_flag("test_flag"), "flush 后 flag 应被移除（归零）")


# ════════════════════════════════════════════════════════════
# P0: TempFlagOperator — int/reduce_if_above 分支
# ════════════════════════════════════════════════════════════

func test_tempflag_reduce_if_above_reduced():
	"""reduce_if_above: 条件满足（flag > threshold）-> 扣减并注册对冲"""
	PlayerState.flags["test_flag"] = 100
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "reduce_if_above"
	op.threshold = 50
	op.amount = 30

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 70, "操作后 flag 应为 70（100-30）")
	assert_eq(PlayerState.session_deferred_cleanups.size(), 1, "应注册 1 个清理算子")
	var cleanup = PlayerState.session_deferred_cleanups[0] as FlagOperator
	assert_eq(cleanup.operation, "append", "清理算子 operation 应为 append")
	assert_eq(cleanup.value, 30, "清理算子 value 应为 30（加回）")

	PlayerState.flush_cleanups()
	assert_eq(PlayerState.get_flag("test_flag"), 100, "flush 后 flag 应恢复为 100")


func test_tempflag_reduce_if_above_not_reduced():
	"""reduce_if_above: 条件不满足（flag <= threshold）-> 无操作，不注册清理"""
	PlayerState.flags["test_flag"] = 30
	var op = TempFlagOperator.new()
	op.flag_id = "test_flag"
	op.type = "int"
	op.operation = "reduce_if_above"
	op.threshold = 50
	op.amount = 30

	op.operate()

	assert_eq(PlayerState.get_flag("test_flag"), 30, "条件不满足，flag 不应变化")
	assert_eq(PlayerState.session_deferred_cleanups.size(), 0, "不应注册清理算子")


# ════════════════════════════════════════════════════════════
# P0: FlagRequirement — str 类型比较
# ════════════════════════════════════════════════════════════

func test_flagreq_str_equal():
	"""str/EQUAL: flag 值与期望值相等 -> true"""
	PlayerState.flags["test_flag"] = "hello"
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "str"
	req.operator = REQ_OPERATOR.COMPARE.EQUAL
	req.value = "hello"

	assert_true(req.compare(PlayerState), "str EQUAL 应返回 true")


func test_flagreq_str_not_equal():
	"""str/NOT_EQUAL: flag 值与期望值不同 -> true"""
	PlayerState.flags["test_flag"] = "hello"
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "str"
	req.operator = REQ_OPERATOR.COMPARE.NOT_EQUAL
	req.value = "world"

	assert_true(req.compare(PlayerState), "str NOT_EQUAL 应返回 true")


func test_flagreq_str_equal_different():
	"""str/EQUAL: flag 值与期望值不同 -> false"""
	PlayerState.flags["test_flag"] = "hello"
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "str"
	req.operator = REQ_OPERATOR.COMPARE.EQUAL
	req.value = "world"

	assert_false(req.compare(PlayerState), "str EQUAL 值不同应返回 false")


func test_flagreq_str_not_set():
	"""str: flag 不存在时 null 兜底为 '' -> EQUAL '' 应返回 true"""
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "str"
	req.operator = REQ_OPERATOR.COMPARE.EQUAL
	req.value = ""

	assert_true(req.compare(PlayerState), "null 兜底为 '' 与 '' EQUAL 应返回 true")


# ════════════════════════════════════════════════════════════
# P0: FlagRequirement — int 类型比较
# ════════════════════════════════════════════════════════════

func test_flagreq_int_gt():
	"""int/GREATER_THAN: flag 值大于期望值 -> true"""
	PlayerState.flags["test_flag"] = 100
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "int"
	req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
	req.value = 50

	assert_true(req.compare(PlayerState), "int GT 应返回 true")


func test_flagreq_int_lt():
	"""int/LESS_THAN: flag 值小于期望值 -> true"""
	PlayerState.flags["test_flag"] = 30
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "int"
	req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
	req.value = 100

	assert_true(req.compare(PlayerState), "int LT 应返回 true")


func test_flagreq_int_eq():
	"""int/EQUAL: flag 值等于期望值 -> true"""
	PlayerState.flags["test_flag"] = 50
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "int"
	req.operator = REQ_OPERATOR.COMPARE.EQUAL
	req.value = 50

	assert_true(req.compare(PlayerState), "int EQUAL 应返回 true")


func test_flagreq_int_ne():
	"""int/NOT_EQUAL: flag 值不等于期望值 -> true"""
	PlayerState.flags["test_flag"] = 50
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "int"
	req.operator = REQ_OPERATOR.COMPARE.NOT_EQUAL
	req.value = 100

	assert_true(req.compare(PlayerState), "int NOT_EQUAL 应返回 true")


func test_flagreq_int_not_set():
	"""int: flag 不存在时 null 兜底为 0 -> EQUAL 0 应返回 true"""
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "int"
	req.operator = REQ_OPERATOR.COMPARE.EQUAL
	req.value = 0

	assert_true(req.compare(PlayerState), "null 兜底为 0 与 0 EQUAL 应返回 true")


# ════════════════════════════════════════════════════════════
# P0: FlagRequirement — bool 类型比较
# ════════════════════════════════════════════════════════════

func test_flagreq_bool_has():
	"""bool/GREATER_THAN(has): flag=true, value=false -> true"""
	PlayerState.flags["test_flag"] = true
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "bool"
	req.operator = REQ_OPERATOR.COMPARE.GREATER_THAN
	req.value = false

	assert_true(req.compare(PlayerState), "bool GT (has) 应返回 true")


func test_flagreq_bool_not_has():
	"""bool/LESS_THAN(not_has): flag=true, value=true -> false (1 < 1)"""
	PlayerState.flags["test_flag"] = true
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "bool"
	req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
	req.value = true

	assert_false(req.compare(PlayerState), "bool LT true < true 应返回 false")


func test_flagreq_bool_not_set():
	"""bool: flag 不存在时 null 兜底为 false -> LT true 应返回 true (false < true)"""
	var req = FlagRequirement.new()
	req.flag_id = "test_flag"
	req.type = "bool"
	req.operator = REQ_OPERATOR.COMPARE.LESS_THAN
	req.value = true

	assert_true(req.compare(PlayerState), "null 兜底 false < true 应返回 true")