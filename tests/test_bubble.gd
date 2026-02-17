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
				'options':[
					{ 
						"description": "冲出去与官吏拼命", 
						"is_disabled": true, 
						"disabled_reason": "你手无缚鸡之力，冲出去只会死在乱军之中，无人记录这段历史。",
						"choice_result":{
							"target_uuid":"test1"
						}
					},
					{ 
						"description": "代替老妇去服役", 
						"is_disabled": true, 
						"disabled_reason": "你的身体虚弱，恐怕连长安都走不到。",
						"choice_result":{
							"target_uuid":"test2"
						}
					},
					{ 
						"description": "在墙角默默记录",
						"is_disabled": false, 
						"effect": "record_poem",
						'double_check': true,
						'double_check_reason': '真的要这么做吗？以她的年龄，去了就是必死的结局',
						"choice_result":{
							"target_uuid":"test3"
						}
					}
				],
			}))
