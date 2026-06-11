@tool
class_name Generator extends Resource

## 要依次执行的 operator 队列
@export var operators: Array[BaseOperator] = []

## 计数器 flag ID（在 PlayerState.flags 中自动注册）
@export var counter_flag_id: String = ""

## 耗尽后要锁定的 action 类型（ENUMS.ACTION_TYPE 枚举值）
@export var action_type: int = -1

## Generator 唯一标识
@export var uuid: String = ""

## Generator 显示名称（用于 debug）
@export var name: String = ""


## 消费下一个 operator。
## 返回 true = 还有剩余，false = 已耗尽。
func execute_next() -> bool:
	var step := _read_step()

	# ── 已耗尽，直接返回 ──
	if step >= operators.size():
		Logging.debug("[Generator] %s 已耗尽 (step=%d/%d)" % [name, step, operators.size()])
		return false

	# ── 执行当前 operator ──
	var current_op := operators[step] as BaseOperator
	if current_op:
		Logging.info("[Generator] %s 执行第 %d/%d 步: %s" % [name, step + 1, operators.size(), current_op.get_class()])
		current_op.operate()
	else:
		Logging.warn("[Generator] %s 第 %d 步 operator 为 null，跳过" % [name, step])

	# ── 推进计数器 ──
	step += 1
	if step >= operators.size():
		PlayerState.remove_flag(counter_flag_id)
		Logging.info("[Generator] %s 已耗尽，移除 flag: %s" % [name, counter_flag_id])
		return false
	else:
		PlayerState.set_flag(counter_flag_id, step, 'int')
		Logging.debug("[Generator] %s 推进到第 %d 步" % [name, step])
		return true


## 检查 generator 是否已耗尽。
func is_consumed() -> bool:
	var step := _read_step()
	return step >= operators.size()


## 读取当前步骤（从 flag 或默认 0）。
func _read_step() -> int:
	var val = PlayerState.get_flag(counter_flag_id)
	if val == null:
		return 0
	return int(val)
