class_name NamedDSLParser extends GDScript

# ──────────────────────────────────────────────
# 命名参数 DSL 核心解析器
#
# 解析格式：func_name(param1=val1; param2=val2; ...)
#
# 设计原则：
# 1. 函数名编码了 type + action（如 prop_gt, flag_bool_set）
# 2. 参数必须命名，位置无关
# 3. 字符串值用双引号包裹，数字/布尔值裸写
# 4. 顶级 | 分隔多个表达式（| 不在括号内）
# 5. @ 前缀表示动态上下文引用（运行时从 context 解析）
#
# 分层符号（按嵌套层级）：
#   Layer 0: |（顶层表达式分隔符）
#   Layer 1: ;（函数参数分隔符）
#   Layer 2: /（数组元素分隔符）
#
# 示例：
#   prop_gt(name="money"; val=50)
#   trait_has(name="official")
#   flag_bool_set(name="xxx"; val=true)
#   flag_str_set(name=@initiator_flag; val="TR_Drunk")  # name 动态解析
#   prop_add(name="money"; val=100)|trait_add(name="corrupt")
#
# Debug 要求：
# - 每个分支都有 logging.err 日志
# - 解析失败时返回 null 并打印清晰错误
# ──────────────────────────────────────────────

# 解析结果：函数名 + 参数字典
class ParseResult:
	var func_name: String = ""
	var params: Dictionary = {}

# ──────────────────────────────────────────────
# DynamicRef — 动态上下文引用包装器
#
# 当 DSL 参数值以 @ 开头时（如 @initiator_flag），
# _parse_value() 返回 DynamicRef 实例而非原始字符串。
#
# 调用方（MicroDSLParser 工厂方法）检查值类型：
#   if val is NamedDSLParser.DynamicRef:
#       # 运行时从 context 解析
#       op.target_flag_id_from_context = val.context_key
#   else:
#       # 字面量
#       op.flag_id = val
#
# 设计意图：
#   @ 前缀 = "这不是一个值，这是一个指向 context 的指针，
#            具体值在运行时由 init() 解析"
# ──────────────────────────────────────────────
class DynamicRef:
	var context_key: String
	
	func _init(key: String):
		context_key = key
	
	func _to_string() -> String:
		return "DynamicRef(%s)" % context_key

# 解析单个表达式，如 prop_gt(name="money", val=50)
# 返回 ParseResult 或 null
static func parse_single(expr: String) -> ParseResult:
	expr = expr.strip_edges()
	if expr.is_empty():
		Logging.err("NamedDSLParser: 空表达式")
		return null
	
	# 匹配 func_name(...) 模式
	var paren_open = expr.find("(")
	var paren_close = expr.rfind(")")
	
	if paren_open == -1 or paren_close == -1 or paren_close <= paren_open:
		Logging.err("NamedDSLParser: 缺少括号，格式应为 func_name(param=val; ...): %s" % expr)
		return null
	
	var func_name = expr.substr(0, paren_open).strip_edges()
	if func_name.is_empty():
		Logging.err("NamedDSLParser: 函数名为空: %s" % expr)
		return null
	
	var params_str = expr.substr(paren_open + 1, paren_close - paren_open - 1).strip_edges()
	
	var result = ParseResult.new()
	result.func_name = func_name
	result.params = _parse_params(params_str)
	
	return result

# 分割多个顶级表达式（| 不在括号内的才是分割符，Layer 0）
# 返回 String 数组
static func split_expressions(data: String) -> PackedStringArray:
	var expressions: PackedStringArray = []
	var depth = 0
	var current = ""
	
	for i in range(data.length()):
		var c = data[i]
		match c:
			'(':
				depth += 1
				current += c
			')':
				depth -= 1
				current += c
				if depth < 0:
					Logging.err("NamedDSLParser: 括号不匹配: %s" % data)
					return []
			'|':
				if depth == 0:
					var trimmed = current.strip_edges()
					if not trimmed.is_empty():
						expressions.append(trimmed)
					current = ""
				else:
					current += c
			_:
				current += c
	
	# 处理最后一个表达式
	var trimmed = current.strip_edges()
	if not trimmed.is_empty():
		expressions.append(trimmed)
	
	return expressions

# 解析参数列表字符串为 Dictionary
# 输入: name="money"; val=50
# 输出: {"name": "money", "val": 50}
static func _parse_params(params_str: String) -> Dictionary:
	var params: Dictionary = {}
	
	if params_str.is_empty():
		return params
	
	# 按 ; 分割参数（Layer 1，处理嵌套括号）
	var depth = 0
	var current = ""
	
	for i in range(params_str.length()):
		var c = params_str[i]
		match c:
			'(', '[':
				depth += 1
				current += c
			')', ']':
				depth -= 1
				current += c
				if depth < 0:
					Logging.err("NamedDSLParser: 括号/方括号不匹配: %s" % params_str)
					return {}
			';':
				if depth == 0:
					_parse_single_param(current.strip_edges(), params)
					current = ""
				else:
					current += c
			_:
				current += c
	
	# 最后一个参数
	if not current.strip_edges().is_empty():
		_parse_single_param(current.strip_edges(), params)
	
	return params

# 解析单个 key=value 参数
static func _parse_single_param(param_str: String, params: Dictionary) -> void:
	param_str = param_str.strip_edges()
	if param_str.is_empty():
		return
	
	var eq_idx = param_str.find("=")
	if eq_idx == -1:
		Logging.err("NamedDSLParser: 参数缺少 = 号: %s" % param_str)
		return
	
	var key = param_str.substr(0, eq_idx).strip_edges()
	var val_str = param_str.substr(eq_idx + 1).strip_edges()
	
	if key.is_empty():
		Logging.err("NamedDSLParser: 参数名为空: %s" % param_str)
		return
	
	# 解析值
	params[key] = _parse_value(val_str)

# 解析值为正确的类型（字符串/整数/浮点数/布尔值/动态引用/数组）
# 类型推断优先级：@动态引用 > [数组] > "双引号字符串" > 布尔值 > 整数 > 浮点数 > 裸字符串
# 裸字符串（无引号）是标准用法，不产生任何 WARN
# ─── Named Amount 符号表 ───
static var _named_amounts_cache: Dictionary = {}

static func _load_named_amounts() -> Dictionary:
	if not _named_amounts_cache.is_empty():
		return _named_amounts_cache
	var path := "res://tools/data/named_amounts.json"
	if not FileAccess.file_exists(path):
		Logging.warn("NamedDSLParser: named_amounts.json 不存在: %s" % path)
		return _named_amounts_cache
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Logging.err("NamedDSLParser: 无法打开 named_amounts.json")
		return _named_amounts_cache
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		Logging.err("NamedDSLParser: named_amounts.json 解析失败: %s" % json.get_error_message())
		return _named_amounts_cache
	var data = json.get_data()
	if data is Dictionary:
		for key in data:
			if not key.begins_with("_"):
				_named_amounts_cache[key] = data[key]
	Logging.info("NamedDSLParser: 加载 named_amounts.json 完成，共 %d 个条目" % _named_amounts_cache.size())
	return _named_amounts_cache

static func _parse_value(val_str: String) -> Variant:
	val_str = val_str.strip_edges()
	
	if val_str.is_empty():
		Logging.err("NamedDSLParser: 值为空")
		return ""
	
	# 🚨 动态上下文引用（@ 前缀）
	# 优先级最高：@xxx 不是字面量字符串，而是"运行时从 context 解析的指针"
	# 调用方通过 is DynamicRef 判断，决定塞 flag_id 还是 target_flag_id_from_context
	if val_str.begins_with("@"):
		var key = val_str.substr(1)
		if key.is_empty():
			Logging.err("NamedDSLParser: @ 后面不能为空: %s" % val_str)
			return ""
		Logging.info("NamedDSLParser: 解析为动态引用 @%s" % key)
		return DynamicRef.new(key)
	
	# 🚀 数组字面量: [val1/val2/val3]
	# _parse_params 已确保 [] 内的 / 不会被误分割为顶层参数分隔符
	# 每个元素去除首尾空格和引号包裹，返回 PackedStringArray
	if val_str.begins_with("[") and val_str.ends_with("]"):
		var inner = val_str.substr(1, val_str.length() - 2).strip_edges()
		if inner.is_empty():
			return PackedStringArray()
		var parts = inner.split("/")
		var arr = PackedStringArray()
		for part in parts:
			var clean = part.strip_edges()
			if clean.is_empty():
				continue
			# 去除双引号包裹
			if clean.begins_with("\"") and clean.ends_with("\""):
				clean = clean.substr(1, clean.length() - 2)
			arr.append(clean)
		Logging.info("NamedDSLParser: 解析为数组: %s (size=%d)" % [str(arr), arr.size()])
		return arr
	
	# 显式字符串（双引号包裹）
	if val_str.begins_with("\"") and val_str.ends_with("\""):
		return val_str.substr(1, val_str.length() - 2)
	
	# 布尔值
	var lower = val_str.to_lower()
	if lower == "true" or lower == "t" or lower == "yes":
		return true
	if lower == "false" or lower == "f" or lower == "no":
		return false
	
	# 整数
	if val_str.is_valid_int():
		return val_str.to_int()
	
	# 浮点数
	if val_str.is_valid_float():
		return val_str.to_float()
	
	# 🆕 Named Amount 符号表查表：在 fallback 裸字符串之前先解析
	# 例如 val=big_amount_money → 查 named_amounts.json → 返回 30
	var amounts := _load_named_amounts()
	if amounts.has(val_str):
		var resolved = amounts[val_str]
		Logging.info("NamedDSLParser: named amount '%s' → %s" % [val_str, str(resolved)])
		return resolved
	
	# fallback: 裸字符串（无引号）— 正确的 DSL 语法，直接返回
	return val_str

# ─── 便捷查询方法 ───

# 从 ParseResult 中安全获取字符串参数
static func get_str_param(result: ParseResult, key: String, default: String = "") -> String:
	if result.params.has(key):
		var val = result.params[key]
		if val is String:
			return val
		Logging.warn("NamedDSLParser: 参数 %s 期望 String，实际类型 %s，使用默认值" % [key, typeof(val)])
	return default

# 从 ParseResult 中安全获取整数参数
static func get_int_param(result: ParseResult, key: String, default: int = 0) -> int:
	if result.params.has(key):
		var val = result.params[key]
		if val is int or val is float:
			return int(val)
		if val is String:
			var int_val = str(val).to_int()
			if int_val != 0 or str(val) == "0":
				return int_val
		Logging.warn("NamedDSLParser: 参数 %s 无法转为整数: %s" % [key, str(val)])
	return default

# 从 ParseResult 中安全获取布尔参数
static func get_bool_param(result: ParseResult, key: String, default: bool = false) -> bool:
	if result.params.has(key):
		var val = result.params[key]
		if val is bool:
			return val
		if val is String:
			var lower = str(val).to_lower()
			return lower == "true" or lower == "t" or lower == "yes" or lower == "1"
		if val is int:
			return val != 0
		Logging.warn("NamedDSLParser: 参数 %s 无法转为布尔: %s" % [key, str(val)])
	return default
