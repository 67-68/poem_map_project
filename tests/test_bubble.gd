@tool
extends Node2D
@export var test_bubble := false:
	set(val):
		if val:
			test_bubble = false
			Global.request_create_bubble.emit(self,'test')
			position.x -= 100
			Global.request_create_bubble.emit(self,'test2')