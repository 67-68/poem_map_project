extends TextureButton

func _on_pressed() -> void:
	EventBus.request_change_left_panel_visibility.emit()
