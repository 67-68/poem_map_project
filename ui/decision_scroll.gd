class_name DecisionScroll extends SmoothScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerState.location_changed.connect(func(): refresh_current_decisions())
	EventBus.year_changed.connect(func(_year: float): refresh_current_decisions())
	refresh_current_decisions()
	
func refresh_current_decisions():
	#breakpoint
	var location = PlayerState.get_location()
	if not location:
		Logging.err('do not find location %s' % PlayerState.current_location)
		return
	
	for child in $V.get_children():
		child.queue_free()
	
	var current_year: float = GameState.year
	var decisions = []
	for d_uuid in Database.get_decisions_all():
		var d = Database.get_decision(d_uuid)
		
		# 1. 检查是否已被禁用
		if d.disabled:
			continue
		
		# 2. 检查时间窗口
		if d.available_from >= 0 and current_year < d.available_from:
			continue
		if d.available_until >= 0 and current_year > d.available_until:
			continue
		
		# 3. 检查前置需求（aciton_requirements）
		var req_passed = true
		if d.aciton_requirements:
			for req in d.aciton_requirements:
				if not req.compare(PlayerState):
					req_passed = false
					break
		if not req_passed:
			continue
		
		# 4. 检查地区标签
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
