@tool
class_name ContextFirstOperator extends BaseOperator

## 上下文数组首项提取算子
##
## 从 context[source_key] 中取出数组的第一项，存入 context[target_key]。
## 用于桥接 RandomPickOperator（永远存 Array[String]）和
## ContextFetchOperators（期望 String key）之间的类型不匹配。

## 源 context key（预期值为 Array[String]）
@export var source_key: String = ""

## 目标 context key（存入提取后的 String）
@export var target_key: String = ""

## 当数组为空或非数组类型时的兜底值
@export var fallback_value: String = ""


func init(_context: Dictionary) -> Dictionary:
	if source_key.is_empty():
		Logging.err("ContextFirstOperator.init: source_key is empty")
		return _context

	if target_key.is_empty():
		Logging.err("ContextFirstOperator.init: target_key is empty")
		return _context

	if not _context.has(source_key):
		Logging.err("ContextFirstOperator.init: context key '%s' not found" % source_key)
		_context[target_key] = fallback_value
		return _context

	var value = _context[source_key]

	if value is Array:
		if value.is_empty():
			Logging.warn("ContextFirstOperator.init: context[%s] is empty array, using fallback" % source_key)
			_context[target_key] = fallback_value
		else:
			var first = value[0]
			if first != null:
				_context[target_key] = str(first)
				Logging.info("ContextFirstOperator.init: extracted first element '%s' from context[%s] -> context[%s]" % [str(first), source_key, target_key])
			else:
				Logging.warn("ContextFirstOperator.init: first element of context[%s] is null, using fallback" % source_key)
				_context[target_key] = fallback_value
	elif value is String:
		_context[target_key] = value
		Logging.info("ContextFirstOperator.init: context[%s] is already a String, passing through" % source_key)
	else:
		Logging.warn("ContextFirstOperator.init: context[%s] is type %s, not Array or String, using fallback" % [source_key, typeof(value)])
		_context[target_key] = fallback_value

	return _context


func operate() -> void:
	pass
