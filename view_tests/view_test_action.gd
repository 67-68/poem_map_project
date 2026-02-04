class_name ViewTestAction extends RefCounted
var description := ''
var callback: Callable

func _init(_description: String,_callback: Callable):
	description = _description
	callback = _callback