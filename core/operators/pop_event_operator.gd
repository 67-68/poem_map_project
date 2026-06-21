@tool
class_name PopEventOperator extends BaseOperator

## 回归过渡文本 — pop_event 时传递给 NarrativeOverlay，
## 与目标事件的 on_returned 合并打印为 NarrativeText 条目。
## 通过 DSL `pop_event(text="...")` 注入，默认空字符串向后兼容。
@export var transition_text: String = ""

func operate():
	Logging.info("PopEventOperator: Popping event from stack, transition_text='%s'" % transition_text)
	EventBus.pop_event.emit(transition_text)
