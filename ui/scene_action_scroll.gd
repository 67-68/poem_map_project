class_name SceneActionScroll extends ScrollContainer

## 大地图行动 main_tag 前缀（第三个 ":" 之前的部分）。
## 匹配到的行动不由 Scroll 创建卡片，而是由 world/action_map.gd 的按钮接管。
const MAIN_ACTION_PREFIXES: Array[String] = [
	"action:main:baiye",
	"action:main:jiaoyou",
	"action:main:denggao",
	"action:main:fangshi",
	"action:main:duzhuo",
	"action:main:fengzhao",
]

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
		# 大地图行动不由 Scroll 卡片承载，跳过
		var is_main_action := false
		var tag: String = a.main_tag
		for prefix in MAIN_ACTION_PREFIXES:
			if tag.begins_with(prefix):
				is_main_action = true
				break
		if is_main_action:
			Logging.info("[SceneActionScroll] 跳过大地图行动卡片: %s" % a.name)
			continue

		# 添加到VBoxContainer的子类
		#breakpoint
		var card = preload("res://ui/scene_action_panel.tscn").instantiate()
		card.initialize(a)
		$V.add_child(card)


# 刷新场景化行动
func _ready():
	refresh()
	TimeService.on_month_tick.connect(refresh)
	EventBus.request_refresh_action_panel.connect(refresh)
