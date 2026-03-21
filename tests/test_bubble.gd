@tool
extends Node2D
@export var test_bubble := false:
	set(val):
		if val:
			test_bubble = false
			Global.request_add_event.emit(self,'test')
			position.x -= 100
			Global.request_add_event.emit(self,'test2')

@export var test_focus_chat := false:
	set(val):
		if val:
			test_focus_chat = false
			Global.request_add_event.emit(FocusedChat.new({
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
						"description": "亮出官身，让官兵退下", 
						"property_requirement": {
							'requirement': PROPERTIES.to_str(PROPERTIES.OFFICIAL_PRESTIGE) + ">50",
							"failed_hint": "你名气不够大，官兵认不得你"
						}
					},
					{
						"description": "在墙角默默记录",
						"is_disabled": false, 
						"effect": "record_poem",
						'double_check': true,
						'double_check_reason': '真的要这么做吗？以她的年龄，去了就是必死的结局',
						"choice_result":{
							"target_uuid":"dufu_fail_to_become_official"
						}
					}
				],
			}))


@export var test := false:
	set(val):
		if val:
			test = false
			var data = Global.event_data['event_test_hub']
			Global.request_narrative.emit(data)
