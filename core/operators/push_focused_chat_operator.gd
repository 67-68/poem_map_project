@tool
class_name PushFocusedChatOperator extends BaseOperator

## 要推送的 FocusedChat 的 UUID
@export var chat_uuid: String

## 当前事件的 context，在 init 时注入
var _captured_context: Dictionary = {}

func operate():
	var focused_chat = Database.focused_chat_data.get(chat_uuid)
	if not focused_chat:
		Logging.err("PushFocusedChatOperator: FocusedChat not found: %s" % chat_uuid)
		return
	Logging.info("PushFocusedChatOperator: Pushing focused chat: %s" % chat_uuid)
	EventBus.push_focused_chat.emit(focused_chat)

func init(context: Dictionary) -> Dictionary:
	_captured_context = context.duplicate()
	Logging.info("PushFocusedChatOperator.init: captured context for chat %s" % chat_uuid)
	return context
