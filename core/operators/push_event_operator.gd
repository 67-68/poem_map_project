@tool
class_name PushEventOperator extends BaseOperator

## 要推送的事件 key（支持 BaseEvent 的 uuid 或 String key）
@export var event_key: String

## 当前事件的 context，在 init 时注入，emit 时一并传递
var _captured_context: Dictionary = {}

## 选项: 注入 interrupt_event 到 context 的按钮文本
## 非空时，会向 _captured_context 注入 { "interrupt_event": { "text": ..., "event_key": ... } }
## 这样被推送的事件会显示中断按钮
@export var inject_interrupt_text: String = ""

## 选项: 注入 interrupt_event 到 context 的目标事件 key
## 与 inject_interrupt_text 配合使用
@export var inject_interrupt_event_key: String = ""

func operate():
	Logging.info("PushEventOperator: Pushing event with key: %s, context keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	if _captured_context.has("guests"):
		Logging.info("PushEventOperator: guests value = %s" % str(_captured_context.get("guests")))
	EventBus.push_event.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	
	# 如果配置了 inject_interrupt，注入到 captured context
	if not inject_interrupt_text.is_empty() and not inject_interrupt_event_key.is_empty():
		_captured_context["interrupt_event"] = {
			"text": inject_interrupt_text,
			"event_key": inject_interrupt_event_key
		}
		Logging.info("PushEventOperator.init: injected interrupt_event into context, text='%s', event_key='%s'" % [inject_interrupt_text, inject_interrupt_event_key])
	
	Logging.info("PushEventOperator.init: captured context for event %s, keys: %s, has guests: %s" % [event_key, _captured_context.keys(), _captured_context.has("guests")])
	return context
