@tool
extends RefCounted

# ═══════════════════════════════════════════════════════
# ChainDSLParser — 事件链 DSL 命令解析器
#
# 解析 DSL 字符串为 ChainCommand 对象。
# 复用 NamedDSLParser 进行基础解析，然后在本地映射函数名 → ChainCommand。
#
# DSL 语法（与 NamedDSLParser 兼容）：
#   create_hierarchy(source="event_A"; source_opt="opt_go"; target="event_B")
#   create_reversible_hierarchy(a="event_A"; a_opt="opt_go"; b="event_B"; b_opt="opt_back")
#   create_once_option(event="event_X"; opt="opt_use")
#
# 也可批量解析（| 分隔）：
#   create_hierarchy(...)|create_once_option(...)
#
# ⚠️ --script 模式下 class_name 不可用，全部用 preload 替代
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（替代 class_name） ───
const SafeLogger = preload("res://parser/safe_logger.gd")
const NamedDSLParser = preload("res://parser/named_dsl_parser.gd")
const ChainCommand = preload("res://parser/chain_command.gd")

# ─── 函数名常量 ───
const FUNC_CREATE_HIERARCHY := "create_hierarchy"
const FUNC_CREATE_REVERSIBLE_HIERARCHY := "create_reversible_hierarchy"
const FUNC_CREATE_ONCE_OPTION := "create_once_option"


# ═══════════════════════════════════════════════════════
# 统一入口
# ═══════════════════════════════════════════════════════

# 解析单条 DSL 命令
# 输入: "create_hierarchy(source="event_A"; source_opt="opt_go"; target="event_B")"
# 返回: ChainCommand 或 null
static func parse_single(dsl: String) -> ChainCommand:
	if dsl.is_empty():
		SafeLogger.err("[ChainDSLParser] 空 DSL 字符串")
		return null

	# 复用 NamedDSLParser 解析函数名 + 参数字典
	var parsed = NamedDSLParser.parse_single(dsl)
	if parsed == null:
		SafeLogger.err("[ChainDSLParser] NamedDSLParser 解析失败: %s" % dsl)
		return null

	# 按函数名分发
	match parsed.func_name:
		FUNC_CREATE_HIERARCHY:
			return _build_create_hierarchy(parsed, dsl)
		FUNC_CREATE_REVERSIBLE_HIERARCHY:
			return _build_create_reversible_hierarchy(parsed, dsl)
		FUNC_CREATE_ONCE_OPTION:
			return _build_create_once_option(parsed, dsl)
		_:
			SafeLogger.err("[ChainDSLParser] 未知命令函数: %s (dsl: %s)" % [parsed.func_name, dsl])
			return null


# 批量解析多条 DSL 命令（| 分隔）
# 输入: "create_hierarchy(...)|create_once_option(...)"
# 返回: Array[ChainCommand]（可能为空）
static func parse_batch(dsl: String) -> Array[ChainCommand]:
	var commands: Array[ChainCommand] = []

	if dsl.is_empty():
		SafeLogger.warn("[ChainDSLParser] 批量解析：空字符串")
		return commands

	# 复用 NamedDSLParser.split_expressions 按 | 分割
	var expressions = NamedDSLParser.split_expressions(dsl)
	if expressions.is_empty():
		SafeLogger.err("[ChainDSLParser] 批量解析：split_expressions 返回空，dsl=%s" % dsl)
		return commands

	for expr in expressions:
		var cmd = parse_single(expr)
		if cmd != null:
			commands.append(cmd)
		else:
			SafeLogger.err("[ChainDSLParser] 批量解析：子表达式解析失败，跳过: %s" % expr)

	SafeLogger.info("[ChainDSLParser] 批量解析完成：%d 条命令 (from: %s)" % [commands.size(), dsl])
	return commands


# ═══════════════════════════════════════════════════════
# 内部构建方法
# ═══════════════════════════════════════════════════════

# create_hierarchy(source="event_A"; source_opt="opt_go"; target="event_B")
static func _build_create_hierarchy(parsed: NamedDSLParser.ParseResult, raw: String) -> ChainCommand:
	var source = NamedDSLParser.get_str_param(parsed, "source")
	var source_opt = NamedDSLParser.get_str_param(parsed, "source_opt")
	var target = NamedDSLParser.get_str_param(parsed, "target")

	if source.is_empty():
		SafeLogger.err("[ChainDSLParser] create_hierarchy 缺少 source 参数: %s" % raw)
		return null
	if source_opt.is_empty():
		SafeLogger.err("[ChainDSLParser] create_hierarchy 缺少 source_opt 参数: %s" % raw)
		return null
	if target.is_empty():
		SafeLogger.err("[ChainDSLParser] create_hierarchy 缺少 target 参数: %s" % raw)
		return null

	var cmd = ChainCommand.create_hierarchy(source, source_opt, target, raw)
	SafeLogger.info("[ChainDSLParser] 解析 create_hierarchy: source=%s, source_opt=%s, target=%s" % [source, source_opt, target])
	return cmd


# create_reversible_hierarchy(a="event_A"; a_opt="opt_go"; b="event_B"; b_opt="opt_back")
static func _build_create_reversible_hierarchy(parsed: NamedDSLParser.ParseResult, raw: String) -> ChainCommand:
	var a = NamedDSLParser.get_str_param(parsed, "a")
	var a_opt = NamedDSLParser.get_str_param(parsed, "a_opt")
	var b = NamedDSLParser.get_str_param(parsed, "b")
	var b_opt = NamedDSLParser.get_str_param(parsed, "b_opt")

	if a.is_empty():
		SafeLogger.err("[ChainDSLParser] create_reversible_hierarchy 缺少 a 参数: %s" % raw)
		return null
	if a_opt.is_empty():
		SafeLogger.err("[ChainDSLParser] create_reversible_hierarchy 缺少 a_opt 参数: %s" % raw)
		return null
	if b.is_empty():
		SafeLogger.err("[ChainDSLParser] create_reversible_hierarchy 缺少 b 参数: %s" % raw)
		return null
	if b_opt.is_empty():
		SafeLogger.err("[ChainDSLParser] create_reversible_hierarchy 缺少 b_opt 参数: %s" % raw)
		return null

	var cmd = ChainCommand.create_reversible_hierarchy(a, a_opt, b, b_opt, raw)
	SafeLogger.info("[ChainDSLParser] 解析 create_reversible_hierarchy: a=%s, a_opt=%s, b=%s, b_opt=%s" % [a, a_opt, b, b_opt])
	return cmd


# create_once_option(event="event_X"; opt="opt_use")
static func _build_create_once_option(parsed: NamedDSLParser.ParseResult, raw: String) -> ChainCommand:
	var event = NamedDSLParser.get_str_param(parsed, "event")
	var opt = NamedDSLParser.get_str_param(parsed, "opt")

	if event.is_empty():
		SafeLogger.err("[ChainDSLParser] create_once_option 缺少 event 参数: %s" % raw)
		return null
	if opt.is_empty():
		SafeLogger.err("[ChainDSLParser] create_once_option 缺少 opt 参数: %s" % raw)
		return null

	var cmd = ChainCommand.create_once_option(event, opt, raw)
	SafeLogger.info("[ChainDSLParser] 解析 create_once_option: event=%s, opt=%s" % [event, opt])
	return cmd
