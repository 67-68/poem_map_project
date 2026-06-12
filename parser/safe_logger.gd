@tool
class_name SafeLogger extends RefCounted

# ═══════════════════════════════════════════════════════
# SafeLogger — 安全的日志封装（不依赖 Logging autoload）
#
# 在 @tool headless 模式下，Logging autoload 不可用。
# 此封装完全不引用 Logging，直接使用 print/printerr，
# 配合标签前缀（[ChainTresEditor], [ChainExecutor] 等）
# 让日志在编辑器 Output 或 CLI stdout 中都可读。
#
# 如需将日志接入 Logging autoload，可在调用方包装。
# ═══════════════════════════════════════════════════════

static func info(msg: String) -> void:
	print("[INFO] " + msg)

static func err(msg: String) -> void:
	printerr("[ERR] " + msg)

static func warn(msg: String) -> void:
	print("[WARN] " + msg)

static func debug(msg: String) -> void:
	print("[DEBUG] " + msg)
