class_name DebugPoemPopup extends RefCounted

func create_debug_view(idx: int):
	var view_scene := preload('res://features/poem_popup.tscn')
	var view = view_scene.instantiate()
	match idx:
		0:
			view