@tool
extends Node2D
@export var test_bubble := false:
	set(val):
		if val:
			test_bubble = false
			Global.request_create_bubble.emit(self,'test')
			position.x -= 100
			Global.request_create_bubble.emit(self,'test2')

@export var test_focus_chat := false:
	set(val):
		if val:
			test_focus_chat = false
			Global.request_full_chat.emit(FocusedChat.new({
				'chats':[
					{
						'chat_position':"RIGHT",
						'name':"长🪞",
						'description':'你好~',
						'texture':'火柴人.png'
					},
					{
						'chat_position':"LEFT",
						'name':"你",
						'description':'找我有什么事？忙着尾随杜甫呢',
						'texture':'火柴人.png'
					}
				],
				'icon':'石壕吏.png',
				'options': [
					{

					}
				]
			}))
