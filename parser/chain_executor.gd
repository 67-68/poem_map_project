@tool
extends RefCounted

# ═══════════════════════════════════════════════════════
# ChainExecutor — 事件链命令编排执行器
#
# 职责：
#   接收 ChainCommand，按命令类型编排执行流程：
#   1. CREATE_HIERARCHY:         加载源事件 → 注入 PushEventOperator → 保存
#   2. CREATE_REVERSIBLE_HIERARCHY:  加载 A/B 事件 → 注入 Push + Pop → 保存
#   3. CREATE_ONCE_OPTION:       加载事件 → 注入 FlagRequirement + FlagOperator → 保存
#
# 依赖：
#   - ChainTresEditor: .tres 定位/加载/注入/保存
#   - ChainFlagGenerator: flag_id 生成
#
# ⚠️ --script 模式下 class_name 不可用，全部用 preload 替代
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（替代 class_name） ───
const SafeLogger = preload("res://parser/safe_logger.gd")
const ChainCommand = preload("res://parser/chain_command.gd")
const ChainTresEditor = preload("res://parser/chain_tres_editor.gd")
const ChainFlagGenerator = preload("res://parser/chain_flag_generator.gd")
const PushEventOperator = preload("res://core/operators/push_event_operator.gd")
const PopEventOperator = preload("res://core/operators/pop_event_operator.gd")
const FlagRequirement = preload("res://core/requirements/flag_requirement.gd")
const FlagOperator = preload("res://core/operators/flag_operator.gd")
const REQ_OPERATOR = preload("res://core/model/requirement_operator.gd")

# ─── 执行结果 ───
class ExecResult:
	var success: bool = false
	var message: String = ""
	var command: ChainCommand = null

	func _init(success_: bool, message_: String, command_: ChainCommand):
		success = success_
		message = message_
		command = command_


# ═══════════════════════════════════════════════════════
# 统一入口
# ═══════════════════════════════════════════════════════

# 执行单条命令
static func execute(command: ChainCommand) -> ExecResult:
	if command == null:
		return ExecResult.new(false, "[ChainExecutor] 命令为 null", null)

	SafeLogger.info("[ChainExecutor] 执行命令: %s" % str(command))

	match command.type:
		ChainCommand.CommandType.CREATE_HIERARCHY:
			return _execute_create_hierarchy(command)
		ChainCommand.CommandType.CREATE_REVERSIBLE_HIERARCHY:
			return _execute_create_reversible_hierarchy(command)
		ChainCommand.CommandType.CREATE_ONCE_OPTION:
			return _execute_create_once_option(command)
		_:
			return ExecResult.new(false, "[ChainExecutor] 未知命令类型: %d" % command.type, command)


# 批量执行多条命令
# 返回 (success_count, fail_count, results)
static func execute_batch(commands: Array[ChainCommand]) -> Dictionary:
	var success_count := 0
	var fail_count := 0
	var results: Array[ExecResult] = []

	for cmd in commands:
		var result = execute(cmd)
		results.append(result)
		if result.success:
			success_count += 1
		else:
			fail_count += 1

	SafeLogger.info("[ChainExecutor] 批量执行完成: %d 成功, %d 失败 (共 %d 条)" % [success_count, fail_count, commands.size()])
	return {
		"success_count": success_count,
		"fail_count": fail_count,
		"results": results,
	}


# ═══════════════════════════════════════════════════════
# 命令执行器
# ═══════════════════════════════════════════════════════

# ─── 1. CREATE_HIERARCHY ───
#
# source(source_opt) ──[Push(target)]──► target
# source 的 source_opt 被注入 PushEventOperator(event_key=target)
# target 不被修改，其结束流向由 target 自己的选项决定
static func _execute_create_hierarchy(command: ChainCommand) -> ExecResult:
	var source = command.params.get("source", "")
	var source_opt = command.params.get("source_opt", "")
	var target = command.params.get("target", "")

	if source.is_empty() or source_opt.is_empty() or target.is_empty():
		return ExecResult.new(false, "[ChainExecutor] create_hierarchy 参数不完整: %s" % str(command.params), command)

	# 创建 PushEventOperator
	var push_op = PushEventOperator.new()
	push_op.event_key = target

	# 注入到源事件的选项
	var success = ChainTresEditor.load_find_inject_save(source, source_opt, push_op)
	if not success:
		return ExecResult.new(false, "[ChainExecutor] create_hierarchy 失败: source=%s, source_opt=%s, target=%s" % [source, source_opt, target], command)

	return ExecResult.new(true, "[ChainExecutor] create_hierarchy 成功: %s(%s) ──[Push(%s)]──► %s" % [source, source_opt, target, target], command)


# ─── 2. CREATE_REVERSIBLE_HIERARCHY ───
#
# a(a_opt) ──[Push(b)]──► b ──[Pop]──► a
# a 的 a_opt 被注入 PushEventOperator(event_key=b)
# b 的 b_opt 被注入 PopEventOperator
static func _execute_create_reversible_hierarchy(command: ChainCommand) -> ExecResult:
	var a = command.params.get("a", "")
	var a_opt = command.params.get("a_opt", "")
	var b = command.params.get("b", "")
	var b_opt = command.params.get("b_opt", "")

	if a.is_empty() or a_opt.is_empty() or b.is_empty() or b_opt.is_empty():
		return ExecResult.new(false, "[ChainExecutor] create_reversible_hierarchy 参数不完整: %s" % str(command.params), command)

	# 1. 创建 PushEventOperator 注入到 A 的选项
	var push_op = PushEventOperator.new()
	push_op.event_key = b
	var success_a = ChainTresEditor.load_find_inject_save(a, a_opt, push_op)
	if not success_a:
		return ExecResult.new(false, "[ChainExecutor] create_reversible_hierarchy 失败: 无法注入 Push 到 %s(%s)" % [a, a_opt], command)

	# 2. 创建 PopEventOperator 注入到 B 的选项
	var pop_op = PopEventOperator.new()
	var success_b = ChainTresEditor.load_find_inject_save(b, b_opt, pop_op)
	if not success_b:
		return ExecResult.new(false, "[ChainExecutor] create_reversible_hierarchy 失败: 无法注入 Pop 到 %s(%s)（Push 已注入 %s）" % [b, b_opt, a], command)

	return ExecResult.new(true, "[ChainExecutor] create_reversible_hierarchy 成功: %s(%s) ──[Push]──► %s ──[Pop]──► %s" % [a, a_opt, b, b_opt], command)


# ─── 3. CREATE_ONCE_OPTION ───
#
# 往选项注入：
#   - requirement: flag_bool_not_has(name="flag_once_{event}_{opt}")
#   - choice_result.operators: [+ flag_bool_set(name="flag_once_{event}_{opt}"; val=true)]
#
# Flag 命名约定：flag_once_{event_key}_{opt_uuid}
# Flag 类型：bool
# 虚注册：运行时由 FlagOperator.init() 处理
static func _execute_create_once_option(command: ChainCommand) -> ExecResult:
	var event_key = command.params.get("event", "")
	var opt_uuid = command.params.get("opt", "")

	if event_key.is_empty() or opt_uuid.is_empty():
		return ExecResult.new(false, "[ChainExecutor] create_once_option 参数不完整: %s" % str(command.params), command)

	# 1. 生成 flag_id
	var flag_id = ChainFlagGenerator.generate_once_flag_id(event_key, opt_uuid)
	if flag_id.is_empty():
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 无法生成 flag_id", command)

	# 2. 创建 flag_bool_not_has requirement
	var req = FlagRequirement.new()
	req.flag_id = flag_id
	req.type = "bool"
	req.operator = REQ_OPERATOR.COMPARE.LESS_THAN  # less than true = not has
	req.value = true

	# 3. 创建 flag_bool_set operator
	var flag_op = FlagOperator.new()
	flag_op.flag_id = flag_id
	flag_op.type = "bool"
	flag_op.operation = "set"
	flag_op.value = true

	# 4. 注入 requirement 到选项
	var event = ChainTresEditor.load_event(event_key)
	if event == null:
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 无法加载事件 '%s'" % event_key, command)

	var option = ChainTresEditor.find_option(event, opt_uuid)
	if option == null:
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 在事件 '%s' 中未找到选项 '%s'" % [event_key, opt_uuid], command)

	# 设置 requirement
	if not ChainTresEditor.set_requirement(option, req):
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 设置 requirement 失败", command)

	# 注入 flag operator
	if not ChainTresEditor.inject_operator(option, flag_op):
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 注入 operator 失败", command)

	# 保存
	if not ChainTresEditor.save_event(event, event_key):
		return ExecResult.new(false, "[ChainExecutor] create_once_option: 保存事件 '%s' 失败" % event_key, command)

	return ExecResult.new(true, "[ChainExecutor] create_once_option 成功: %s(%s) [flag=%s]" % [event_key, opt_uuid, flag_id], command)
