@tool
extends Node2D
@export var test_bubble := false:
	set(val):
		if val:
			test_bubble = false
			EventBus.request_add_chat.emit(self,'test')
			position.x -= 100
			EventBus.request_add_chat.emit(self,'test2')

@export var test := false:
	set(val):
		if val:
			test = false
			var data = Database.history_events['event_test_hub']
			EventBus.request_event.emit(data)
