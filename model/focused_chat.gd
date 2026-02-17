# 那种有立绘的Chat
class_name FocusedChat extends WorldEvent

var chats: Array # list[list[str, int]] # int -> Chatposition
# 使用父类的icon作为背景图
var options: Array = [] # list[EventOptions]; 在对话结束之后被展示

func _init(data: Dictionary):
	super._init(data)
	var props = data.get("properties", data.get("property", {}))

	var raw_chats = data.get('chats',props.get('chats',{}))
	for c in raw_chats:
		var chat = FocusedChatLine.new(c)
		chats.append(chat)
	
	var raw_options = data.get('options',props.get('options',[]))
	if raw_options:
		for op in raw_options:
			options.append(EventOption.new(op))
