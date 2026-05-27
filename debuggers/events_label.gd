extends Label

var base_text = "future events"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	#breakpoint
	text = base_text
	for e in TimeService.event_queue:
		text += ": " + str(e["time"])
		if e.get("entity"): text += " - " + e.get("entity").name
		text += "\n"
