# 那种有立绘的Chat
class_name FocusedChat extends GameEntity

@export var chats: Array[FocusedChatLine] # list[list[str, int]] # int -> Chatposition
# 使用父类的icon作为背景图
@export var options: Array[BaseOption] = [] # list[BaseOptions]; 在对话结束之后被展示