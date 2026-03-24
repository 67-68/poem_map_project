extends ScrollContainer

func refresh():
	"""
	刷新scene action
	提供最多六个
	算法：权重加和，
	"""
	var available_actions = ActionManager.get_available_scene_actions()
	var selected_actions = ActionManager.pick_top_actions(available_actions)
	Logging.info("SceneActionScroll" + "Selected actions: " + str(selected_actions))
	for a in selected_actions as Action:
		SceneActionPanel.new(a)

# 刷新场景化行动
func _ready():
	TimeService.on_month_tick.connect(refresh)