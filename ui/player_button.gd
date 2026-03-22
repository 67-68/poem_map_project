extends TextureButton

func _on_pressed() -> void:
	Global.request_change_left_panel_visibility.emit()
