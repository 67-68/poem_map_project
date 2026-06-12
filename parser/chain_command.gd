@tool
class_name ChainCommand extends Resource

# ═══════════════════════════════════════════════════════
# ChainCommand — 事件链命令数据类
#
# 表示一条事件链构建命令，由 ChainDSLParser 解析 DSL 字符串生成，
# 由 ChainExecutor 消费执行。
#
# 三种命令类型：
#   1. CREATE_HIERARCHY:        单向层级 Push
#   2. CREATE_REVERSIBLE_HIERARCHY:  双向层级 Push + Pop
#   3. CREATE_ONCE_OPTION:      仅可点击一次的选项（Flag 守卫）
# ═══════════════════════════════════════════════════════

# ─── 命令类型枚举 ───
enum CommandType {
	CREATE_HIERARCHY,            # 单向层级：source_opt → Push(target)
	CREATE_REVERSIBLE_HIERARCHY, # 双向层级：a_opt → Push(b), b_opt → Pop
	CREATE_ONCE_OPTION,          # 一次性选项：Flag 守卫 + Flag 设置
}

# 命令类型（必填）
@export var type: CommandType = -1

# ─── 参数字典（根据 type 不同，包含不同字段） ───
#
# CREATE_HIERARCHY:
#   source: String       — 源事件 key
#   source_opt: String   — 源事件中用来前进的选项 uuid
#   target: String       — 目标事件 key
#
# CREATE_REVERSIBLE_HIERARCHY:
#   a: String            — 事件 A 的 key
#   a_opt: String        — 事件 A 中用来前进到 B 的选项 uuid
#   b: String            — 事件 B 的 key
#   b_opt: String        — 事件 B 中用来返回 A 的选项 uuid
#
# CREATE_ONCE_OPTION:
#   event: String        — 事件 key
#   opt: String          — 选项 uuid（要被标记为仅可点击一次）
@export var params: Dictionary = {}

# 原始 DSL 字符串（用于 debug / 日志）
@export var raw_dsl: String = ""


# ─── 工厂方法（无歧义构造） ───

static func create_hierarchy(source: String, source_opt: String, target: String, raw: String = "") -> ChainCommand:
	var cmd = ChainCommand.new()
	cmd.type = CommandType.CREATE_HIERARCHY
	cmd.params = {
		"source": source,
		"source_opt": source_opt,
		"target": target,
	}
	cmd.raw_dsl = raw
	return cmd


static func create_reversible_hierarchy(a: String, a_opt: String, b: String, b_opt: String, raw: String = "") -> ChainCommand:
	var cmd = ChainCommand.new()
	cmd.type = CommandType.CREATE_REVERSIBLE_HIERARCHY
	cmd.params = {
		"a": a,
		"a_opt": a_opt,
		"b": b,
		"b_opt": b_opt,
	}
	cmd.raw_dsl = raw
	return cmd


static func create_once_option(event: String, opt: String, raw: String = "") -> ChainCommand:
	var cmd = ChainCommand.new()
	cmd.type = CommandType.CREATE_ONCE_OPTION
	cmd.params = {
		"event": event,
		"opt": opt,
	}
	cmd.raw_dsl = raw
	return cmd


# ─── 调试输出 ───

func _to_string() -> String:
	var type_name = CommandType.keys()[type] if type >= 0 and type < CommandType.size() else "UNKNOWN"
	return "ChainCommand(%s: %s)" % [type_name, str(params)]
