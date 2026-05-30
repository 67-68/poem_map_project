@tool
class_name TempFlagOperator extends FlagOperator

## TempFlagOperator — 临时标志位操作符
###
### 与 FlagOperator 功能一致，但在 operate() 时会额外创建一个
### 反向清理算子，注册到 PlayerState.session_deferred_cleanups 中。
### 当会话/场景结束时，调用 PlayerState.flush_cleanups() 逆序回滚所有临时 flag。
###
### 反向策略：
###   bool/set       → 恢复旧值（若无旧值则设为 false，触发移除）
###   str/set        → 恢复旧值（若无旧值则设为 ""，触发移除）
###   str/append     → 恢复旧值（快照还原）
###   int/set        → 恢复旧值（若无旧值则设为 0，触发移除）
###   int/append     → 追加负值对冲
###   int/reduce_if_above → 若实际扣减了，加回 amount


func operate():
	# 1. 捕获操作前的 flag 状态
	var had_flag_before = PlayerState.has_flag(flag_id)
	var old_value = PlayerState.get_flag(flag_id)

	# 2. 执行正常操作
	super.operate()

	# 3. 构造反向清理算子
	var cleanup_op = FlagOperator.new()
	cleanup_op.flag_id = flag_id

	match type:
		"bool":
			cleanup_op.type = "bool"
			cleanup_op.operation = "set"
			if had_flag_before:
				cleanup_op.value = old_value
			else:
				cleanup_op.value = false

		"str":
			cleanup_op.type = "str"
			cleanup_op.operation = "set"
			if had_flag_before:
				cleanup_op.value = old_value
			else:
				cleanup_op.value = ""

		"int":
			cleanup_op.type = "int"
			if operation == "append":
				cleanup_op.operation = "append"
				cleanup_op.value = -int(value)
			elif operation == "reduce_if_above":
				var current_after = PlayerState.get_flag(flag_id)
				var was_reduced = (current_after != null and had_flag_before and int(old_value) > threshold and int(current_after) == int(old_value) - amount)
				if was_reduced:
					cleanup_op.operation = "append"
					cleanup_op.value = amount
				else:
					# 没实际扣减，无需清理
					return
			else:
				# int set
				cleanup_op.operation = "set"
				if had_flag_before:
					cleanup_op.value = old_value
				else:
					cleanup_op.value = 0

	# 4. 注册到 PlayerState 清理队列
	PlayerState.defer_cleanup(cleanup_op)
