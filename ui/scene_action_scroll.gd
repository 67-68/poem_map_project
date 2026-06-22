class_name SceneActionScroll extends SmoothScrollContainer

func refresh():
	"""
	刷新scene action（差分更新）
	提供最多六个
	算法：权重加和，
	"""
	var available_actions = ActionManager.get_available_scene_actions()
	var selected_actions = ActionManager.pick_top_actions(available_actions)
	Logging.info("SceneActionScroll" + "Selected actions: " + str(selected_actions))
	EventBus.selected_actions_change.emit(selected_actions)
	
	var children = $V.get_children()
	var target_count = selected_actions.size()
	var current_count = children.size()
	
	# 1. 更新已有按钮（取 min）
	for i in range(min(current_count, target_count)):
		children[i].update_action(selected_actions[i])
	
	# 2. 多余的销毁
	for i in range(target_count, current_count):
		children[i].queue_free()
	
	# 3. 不足的新建
	for i in range(current_count, target_count):
		var card = preload("res://ui/action_button.tscn").instantiate()
		card.initialize(selected_actions[i])
		$V.add_child(card)


# 刷新场景化行动
func _ready():
	super._ready()
	refresh()
	TimeService.on_month_tick.connect(refresh)
	EventBus.request_refresh_action_panel.connect(refresh)
