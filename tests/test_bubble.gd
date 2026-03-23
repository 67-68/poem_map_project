@tool
extends Node2D
@export var test_bubble := false:
	set(val):
		if val:
			test_bubble = false
			Global.request_add_chat.emit(self,'test')
			position.x -= 100
			Global.request_add_chat.emit(self,'test2')

@export var test := false:
	set(val):
		if val:
			test = false
			var data = Global.history_events['event_test_hub']
			Global.request_event.emit(data)
