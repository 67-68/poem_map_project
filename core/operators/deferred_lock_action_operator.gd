@tool
class_name DeferredLockActionOperator extends BaseOperator

## Generator 要执行的 operator 队列（按顺序依次消费）
@export var sub_operators: Array[BaseOperator] = []

## 计数器 flag ID（在 PlayerState.flags 中自动注册为 int 类型）
## 命名建议：使用反作用域前缀如 "gen_{action_id}_{event_id}"
@export var counter_flag_id: String = ""

## 目标 action 类型（ENUMS.ACTION_TYPE 枚举值）
## generator 耗尽后此 action 会被锁定 1 旬
@export var action_type: ENUMS.ACTION_TYPE = -1

## Generator UUID（用于 debug / 追踪）
@export var generator_uuid: String = ""

## Generator 名称（用于 debug / 展示）
@export var generator_name: String = ""


func operate():
	# ── 1. 参数校验 ──
	if sub_operators.is_empty():
		Logging.warn("[DeferredLockActionOperator] sub_operators 为空，跳过")
		return

	if counter_flag_id.is_empty():
		# 自动生成 counter_flag_id：deferred_lock_{action_type_name}_{n}
		var action_name = ENUMS.ACTION_TYPE.keys()[action_type].to_lower()
		var n := 1
		while true:
			var candidate := "flag_deferred_lock_%s_%d" % [action_name, n]
			if not Database.flags.has(candidate) and not PlayerState.has_flag(candidate):
				counter_flag_id = candidate
				break
			n += 1
		PlayerState.register_virtual_flag(counter_flag_id, 'int')
		Logging.info("[DeferredLockActionOperator] 自动生成 counter_flag_id: %s" % counter_flag_id)

	if action_type < 0 or action_type >= ENUMS.ACTION_TYPE.size():
		Logging.err("[DeferredLockActionOperator] 无效的 action_type: %d" % action_type)
		return

	# ── 2. 查找目标 action ──
	var action_id := ActionManager.action_type_to_id(action_type)
	if action_id.is_empty():
		Logging.err("[DeferredLockActionOperator] 无法解析 action_type %d 的 action_id" % action_type)
		return

	var action := Database.actions.get(action_id) as Action
	if action == null:
		Logging.err("[DeferredLockActionOperator] 未找到 action: %s" % action_id)
		return

	# ── 3. 创建 Generator 并挂到 action ──
	var gen := Generator.new()
	gen.operators = sub_operators.duplicate()
	gen.counter_flag_id = counter_flag_id
	gen.action_type = action_type
	gen.uuid = generator_uuid
	gen.name = generator_name

	if action.generator != null:
		Logging.warn("[DeferredLockActionOperator] 覆盖已有 generator on action '%s' (旧 uuid=%s, 新 uuid=%s)" % [
			action_id,
			action.generator.uuid,
			generator_uuid
		])

	action.generator = gen
	Logging.info("[DeferredLockActionOperator] 已挂载 generator '%s' (uuid=%s) 到 action '%s'，共 %d 步" % [
		generator_name,
		generator_uuid,
		action_id,
		sub_operators.size()
	])


func init(_context: Dictionary) -> Dictionary:
	# 在 init 时注册虚拟 flag，确保 set_flag/get_flag 能通过 _validate_flag_type 校验
	if not counter_flag_id.is_empty():
		PlayerState.register_virtual_flag(counter_flag_id, 'int')
	return _context


# ─── 契约方法 ───

func get_referenced_flags() -> Array:
	if counter_flag_id.is_empty():
		return []
	return [counter_flag_id]

func get_provided_flags() -> Array:
	if counter_flag_id.is_empty():
		return []
	return [counter_flag_id]

func get_demanded_flags() -> Array:
	if counter_flag_id.is_empty():
		return []
	return [counter_flag_id]

func get_referenced_traits() -> Array:
	return []

func get_provided_traits() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
