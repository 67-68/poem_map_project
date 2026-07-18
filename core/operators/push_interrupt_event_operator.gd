@tool
class_name PushInterruptEventOperator extends BaseOperator

## 要推送的事件 key（支持 BaseEvent 的 uuid 或 String key）— 展示事件
@export var event_key: String

## 中断按钮点击后要推送的目标事件 key；为空时默认等于 event_key
@export var interrupt_target_key: String = ""

## 中断按钮上显示的文字
@export var interrupt_text: String = tr("CODE_PUSH_INTERRUPT_EVENT_OPERATOR_F9D19345A0")

## 中断按钮颜色（self_modulate），默认深红色
@export var interrupt_color: Color = Color(0.70, 0.15, 0.30, 1.0)

## 当前事件的 context，在 init 时注入，emit 时一并传递
var _captured_context: Dictionary = {}

func operate():
	Logging.info("PushInterruptEventOperator: Pushing event with interrupt key: %s, context keys: %s" % [event_key, _captured_context.keys()])
	EventBus.push_event.emit(event_key, _captured_context)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()

	# 中断目标：优先用 interrupt_target_key，回退到 event_key
	var target_key: String = interrupt_target_key if not interrupt_target_key.is_empty() else event_key

	# 注入 interrupt_event 到 context，这样被推送的事件会显示中断按钮
	_captured_context["interrupt_event"] = {
		"text": interrupt_text,
		"event_key": target_key,
		"color": interrupt_color
	}
	Logging.info("PushInterruptEventOperator.init: injected interrupt_event into context, text='%s', target='%s', color=%s" % [interrupt_text, target_key, interrupt_color])

	return context
