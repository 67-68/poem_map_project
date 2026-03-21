# 那种有立绘的Chat
class_name FocusedChat extends WorldEvent

var chats: Array[FocusedChatLine] # list[list[str, int]] # int -> Chatposition
# 使用父类的icon作为背景图
var options: Array[EventOption] = [] # list[EventOptions]; 在对话结束之后被展示