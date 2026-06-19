class_name SceneActionScroll extends ScrollContainer

func refresh():
	"""
	刷新scene action
	提供最多六个
	算法：权重加和，
	"""
	# 删除所有VBoxContainer的子类
	for child in $V.get_children():
		child.queue_free()
	var available_actions = ActionManager.get_available_scene_actions()
	var selected_actions = ActionManager.pick_top_actions(available_actions)
	Logging.info("SceneActionScroll" + "Selected actions: " + str(selected_actions))
	EventBus.selected_actions_change.emit(selected_actions)
	for a in selected_actions:
		# 添加到VBoxContainer的子类
		#breakpoint
		var card = preload("res://ui/action_button.tscn").instantiate()
		card.initialize(a)
		$V.add_child(card)


# 刷新场景化行动
func _ready():
	refresh()
	TimeService.on_month_tick.connect(refresh)
	EventBus.request_refresh_action_panel.connect(refresh)
