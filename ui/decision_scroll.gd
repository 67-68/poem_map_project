class_name DecisionScroll extends ScrollContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerState.location_changed.connect(func(): refresh_current_decisions())
	
func refresh_current_decisions():
	var location = PlayerState.get_location()
	if not location:
		Logging.err('do not find location %s' % PlayerState.current_location)
		return
	
	for d in Global.decisions:
		if location.area_tags.contains(d.area_tag):
			# TODO: 创建决策项并添加到滚动容器
			pass
