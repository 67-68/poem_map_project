extends ColorRect


func _ready() -> void:
	visible = false
	if not EventBus.has_signal("request_toggle_debug_overlay"):
		Logging.err("DebugInfo: EventBus 缺少 signal request_toggle_debug_overlay")
		return
	EventBus.request_toggle_debug_overlay.connect(_on_toggle_debug_overlay)


func _on_toggle_debug_overlay() -> void:
	visible = not visible
