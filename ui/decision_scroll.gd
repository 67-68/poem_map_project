class_name DecisionScroll extends ScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerState.location_changed.connect(func(): refresh_current_decisions())
	refresh_current_decisions()
	
func refresh_current_decisions():
	#breakpoint
	var location = PlayerState.get_location()
	if not location:
		Logging.err('do not find location %s' % PlayerState.current_location)
		return
	
	for child in $V.get_children():
		child.queue_free()	
	
	var decisions = []
	for d_uuid in Database.decisions:
		var d = Database.decisions[d_uuid]
		if d.disabled:
			continue
		if not d.area_tags:
			var panel = preload("res://ui/decision_panel.tscn").instantiate()
			panel.inititalization(d)
			$V.add_child(panel)
			decisions.append(d)
			continue
		for t in d.area_tags:
			if t in location.area_tags:
				var panel = preload("res://ui/decision_panel.tscn").instantiate()
				panel.inititalization(d)
				$V.add_child(panel)
				decisions.append(d)
				break
	EventBus.avaialble_decision_change.emit(decisions)
