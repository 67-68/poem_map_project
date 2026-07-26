@tool
extends Node
# class_name Logging

# ═════════════════════════════════════════════════════════════════════════════
# Logging — 统一日志系统（静态内核 + 环形缓冲区）
#
# 本文件既是 Autoload 也是纯静态 API 类：
#   - Logging.info("msg") 调用的是 static func，无论 autoload 是否初始化
#   - 环形缓冲区（500 条）供 RuntimeProbe 的 GET /api/logs 拉取
#   - @tool 模式/headless 下无需依赖场景树
# ═════════════════════════════════════════════════════════════════════════════

enum Level { DEBUG, INFO, WARN, ERROR }

# ── 控制台输出最低级别（debug 不喷控制台，仅进缓冲区）──
static var _min_print_level: int = Level.INFO

# ── 静态环形缓冲区 ──
static var _ring_buffer: Array[Dictionary] = []
static var _seq_counter: int = 0
const MAX_BUFFER_SIZE := 2000

# ── 内部推送 ──
static func _push_to_buffer(level: String, msg: String) -> void:
	var entry := {
		"seq": _seq_counter,
		"timestamp": Time.get_time_string_from_system(),
		"level": level,
		"message": msg
	}
	_seq_counter += 1
	_ring_buffer.append(entry)
	if _ring_buffer.size() > MAX_BUFFER_SIZE:
		_ring_buffer.pop_front()

# ── 核心发射器（双通道，debug 级别默认不喷控制台）──
static func _emit(level: String, msg: String, color: String, level_int: int) -> void:
	var time = Time.get_time_string_from_system()
	# 通道 1: Godot Editor Output / stdout（仅当 >= min_print_level）
	if level_int >= _min_print_level:
		print_rich("[color=%s][%s] [%s] %s[/color]" % [color, time, level, msg])
	# 通道 2: 环形缓冲区 (供 RuntimeProbe 拉取)
	_push_to_buffer(level, msg)

# ═════════════════════════════════════════════════════════════════════════════
# 公共静态 API
# ═════════════════════════════════════════════════════════════════════════════

static func debug(msg: String) -> void: _emit("DEBUG", msg, "gray", Level.DEBUG)
static func info(msg: String)  -> void: _emit("INFO",  msg, "white", Level.INFO)
static func warn(msg: String)  -> void: _emit("WARN",  msg, "yellow", Level.WARN)
static func err(msg: String)   -> void: _emit("ERROR", msg, "red", Level.ERROR)

static func not_exists(source: String, ...obj) -> bool:
	var i := 0
	for o in obj:
		if not o:
			err("the %s object from %s not found" % [i, source])
			return true
		i += 1
	return false

static func done(name: String, domain: String = "") -> void:
	if not domain.is_empty():
		info("[%s] %s done loading" % [domain, name])
		return
	info("%s done loading" % name)

static func change(source, target) -> void:
	info("change %s to %s" % [source, target])

# ═════════════════════════════════════════════════════════════════════════════
# RuntimeProbe 拉取接口（通过 static func 暴露给其他 autoload）
# ═════════════════════════════════════════════════════════════════════════════

static func get_logs_since(since: int, limit: int = 50) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _ring_buffer:
		if entry.seq >= since:
			result.append(entry)
			if result.size() >= limit:
				break
	return result

static func get_total_buffered() -> int:
	return _ring_buffer.size()

static func get_current_seq() -> int:
	return _seq_counter
