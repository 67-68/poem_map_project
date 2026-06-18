@tool
class_name ContextKeyPushEventOperator extends BaseOperator

## 上下文 key 路径，支持点分隔（如 "social_data.do_favor"）
## operate 时从 _captured_context 按此路径读取目标 event_key
@export var context_key: String = ""

## 当前事件的 context，在 init 时注入，operate 时从中读取 event_key 一并传递
var _captured_context: Dictionary = {}

func operate():
	if context_key.is_empty():
		Logging.err("ContextKeyPushEventOperator.operate: context_key 为空，无法读取 event_key")
		return

	# 从 _captured_context 按点分隔路径读取 event_key
	var event_key: String = ""
	if "." in context_key:
		var parts := context_key.split(".")
		var current = _captured_context
		for part in parts:
			if not current is Dictionary:
				Logging.err("ContextKeyPushEventOperator.operate: 无法按路径 '%s' 读取，中间节点 '%s' 不是 Dictionary" % [context_key, part])
				return
			if not current.has(part):
				Logging.err("ContextKeyPushEventOperator.operate: context 中不存在 key '%s'，完整路径: %s" % [part, context_key])
				return
			current = current[part]
		event_key = str(current) if current else ""
	else:
		if not _captured_context.has(context_key):
			Logging.err("ContextKeyPushEventOperator.operate: context 中不存在 key '%s'" % context_key)
			return
		event_key = str(_captured_context[context_key])

	if event_key.is_empty():
		Logging.err("ContextKeyPushEventOperator.operate: 从 context_key='%s' 读取到的 event_key 为空" % context_key)
		return

	Logging.info("ContextKeyPushEventOperator: pushing event '%s' from context_key='%s'" % [event_key, context_key])
	EventBus.push_event.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("ContextKeyPushEventOperator.init: captured context, keys: %s" % _captured_context.keys())
	return context
