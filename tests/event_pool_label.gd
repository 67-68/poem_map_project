extends Label

var event_manager = EventManager

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if event_manager:
		_update_display()

func _update_display():
	var pool_size = event_manager.current_event_pool.size()
	var total_weight = 0.0
	var event_names = []
	
	for event in event_manager.current_event_pool:
		total_weight += event.weight
		event_names.append(event.name)
	
	var display_text = "Event Pool Debug Info:\n"
	display_text += "Pool Size: " + str(pool_size) + "\n"
	display_text += "Total Weight: " + str(total_weight) + "\n"
	display_text += "Events: " + str(event_names)
	
	text = display_text
