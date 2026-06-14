@tool
extends Node

# ═══════════════════════════════════════════════════════
# EventChainBuilder — 事件链构建器 CLI 入口
#
# 使用方式：
#   1. MCP 调用: godot --headless --script parser/event_chain_builder.gd -- <DSL字符串>
#   2. 挂载到 debugger 场景: 在 google_sheet_fetcher.tscn 中附加此脚本后调用 run()
#   3. 手动运行: godot --headless --script parser/event_chain_builder.gd -- "create_hierarchy(...)"
#
# DSL 语法（复用 NamedDSLParser）：
#   create_hierarchy(source="event_A"; source_opt="opt_go"; target="event_B")
#   create_reversible_hierarchy(a="event_A"; a_opt="opt_go"; b="event_B"; b_opt="opt_back")
#   create_once_option(event="event_X"; opt="opt_use")
#
# 批量执行（| 分隔）：
#   create_hierarchy(...)|create_once_option(...)
#
# 输出格式：
#   JSON: {"success": true, "results": [...]}
#
# ⚠️ --script 模式下 class_name 不可用，全部用 preload 替代
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（替代 class_name） ───
const ChainDSLParser = preload("res://parser/chain_dsl_parser.gd")
const ChainExecutor = preload("res://parser/chain_executor.gd")

# ─── 入口 ───

func _ready() -> void:
	# 使用 OS.get_cmdline_user_args() 获取 -- 之后的用户参数
	# Godot 4: --headless scene.tscn -- "DSL" 中，-- 之后的参数通过 user_args 获取
	var user_args = OS.get_cmdline_user_args()
	var dsl := ""

	if not user_args.is_empty():
		# 取最后一个非空非-开头的参数（跳过可能的 .tscn/.gd 路径）
		for i in range(user_args.size() - 1, -1, -1):
			var arg = user_args[i]
			if not arg.is_empty() and not arg.begins_with("-"):
				if arg.ends_with(".tscn") or arg.ends_with(".gd"):
					continue
				dsl = arg
				break

	if dsl.is_empty():
		# fallback: 从常规 args 中取（兼容 --script 模式）
		var all_args = OS.get_cmdline_args()
		for i in range(all_args.size() - 1, -1, -1):
			var arg = all_args[i]
			if not arg.is_empty() and not arg.begins_with("-"):
				if arg.ends_with(".tscn") or arg.ends_with(".gd"):
					continue
				dsl = arg
				break

	if not dsl.is_empty():
		Logging.info("[EventChainBuilder] 命令行模式: %s" % dsl)
		_cli_run(dsl)
		get_tree().quit(0)
	else:
		Logging.info("[EventChainBuilder] 场景模式，等待 run() 调用")
		# 场景模式下不自动退出


# ─── 公开 API ───

# 运行单条 DSL 命令
# 用法: EventChainBuilder.run("create_hierarchy(...)")
static func run(dsl: String) -> Dictionary:
	if dsl.is_empty():
		Logging.err("[EventChainBuilder] run: DSL 为空")
		return _result(false, "DSL 为空", [], [])

	# 1. 解析 DSL 为 ChainCommand
	var commands = ChainDSLParser.parse_batch(dsl)
	if commands.is_empty():
		return _result(false, "DSL 解析失败，未产生任何命令", [], [])

	# 2. 执行所有命令
	var exec_result = ChainExecutor.execute_batch(commands)

	# 3. 构建结果
	var success = exec_result.fail_count == 0
	var messages = []
	for r in exec_result.results as Array:
		messages.append(r.message)

	return _result(success, "执行完成: %d 成功, %d 失败" % [exec_result.success_count, exec_result.fail_count], messages, commands)


# ─── 内部方法 ───

static func _result(success: bool, message: String, messages: Array, commands: Array) -> Dictionary:
	var result = {
		"success": success,
		"message": message,
		"details": messages,
		"command_count": commands.size(),
	}
	if not success:
		Logging.err("[EventChainBuilder] 失败: %s" % message)
	else:
		Logging.info("[EventChainBuilder] 成功: %s" % message)
	return result


func _cli_run(dsl: String) -> void:
	var result = run(dsl)
	# 命令行输出 JSON
	Logging.info(JSON.stringify(result, "\t", false))
	if not result.get("success", false):
		Logging.err("[EventChainBuilder] CLI 执行失败")
	else:
		Logging.info("[EventChainBuilder] CLI 执行成功")
