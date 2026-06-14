@tool
extends RefCounted

# ═══════════════════════════════════════════════════════
# ChainFlagGenerator — 事件链 Flag 生成器
#
# 职责：
#   1. 为 create_once_option 生成 flag_id（遵循命名约定）
#   2. 生成 Micro-DSL 表达式（用于 CSV 兼容）
#
# Flag 命名约定：
#   flag_once_{event_key}_{opt_uuid}
#   示例: flag_once_baiye_asking_for_actual_stuff_opt_001
#
# 虚注册机制：
#   由 FlagOperator.init() 在运行时处理，本类不直接访问 PlayerState。
#
# ⚠️ --script 模式下 class_name 不可用，全部用 preload 替代
# ═══════════════════════════════════════════════════════

# ─── preload 依赖（替代 class_name） ───
const Logging = preload("res://core/logger.gd")

const FLAG_PREFIX := "flag_once_"


# ─── Flag ID 生成 ───

# 为 create_once_option 生成 flag_id
# 格式: flag_once_{event_key}_{opt_uuid}
# 例如: flag_once_baiye_asking_for_actual_stuff_opt_go
static func generate_once_flag_id(event_key: String, opt_uuid: String) -> String:
	if event_key.is_empty() or opt_uuid.is_empty():
		Logging.err("[ChainFlagGenerator] generate_once_flag_id: event_key 或 opt_uuid 为空")
		return ""

	var flag_id = FLAG_PREFIX + event_key + "_" + opt_uuid
	Logging.info("[ChainFlagGenerator] 生成 once flag_id: %s" % flag_id)
	return flag_id


# ─── Flag 类型 ───

# Once-option 使用 bool 类型 flag
static func get_once_flag_type() -> String:
	return "bool"


# ─── Micro-DSL 表达式生成 ───

# 生成 flag_bool_not_has requirement 的 DSL 表达式
# 示例: flag_bool_not_has(name="flag_once_baiye_asking_for_actual_stuff_opt_go")
static func generate_once_requirement_dsl(event_key: String, opt_uuid: String) -> String:
	var flag_id = generate_once_flag_id(event_key, opt_uuid)
	if flag_id.is_empty():
		return ""
	var dsl = 'flag_bool_not_has(name="%s")' % flag_id
	Logging.info("[ChainFlagGenerator] 生成 once requirement DSL: %s" % dsl)
	return dsl


# 生成 flag_bool_set operator 的 DSL 表达式
# 示例: flag_bool_set(name="flag_once_baiye_asking_for_actual_stuff_opt_go"; val=true)
static func generate_once_operator_dsl(event_key: String, opt_uuid: String) -> String:
	var flag_id = generate_once_flag_id(event_key, opt_uuid)
	if flag_id.is_empty():
		return ""
	var dsl = 'flag_bool_set(name="%s"; val=true)' % flag_id
	Logging.info("[ChainFlagGenerator] 生成 once operator DSL: %s" % dsl)
	return dsl
