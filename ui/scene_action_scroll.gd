class_name SceneActionScroll extends SmoothScrollContainer

var _locked_action_ids: Array[String] = []  # 当前灰化显示的 action ID 列表

func refresh():
	"""
	刷新scene action（差分更新）
	提供最多六个选中 + 其余灰化锁定展示
	算法：权重加和，
	"""
	var available_actions = ActionManager.get_available_scene_actions()
	var selected_actions = ActionManager.pick_top_actions(available_actions)
	Logging.info("SceneActionScroll" + "Selected actions: " + str(selected_actions))
	EventBus.selected_actions_change.emit(selected_actions)
	
	# 获取全部 action（含合法但未中签的）
	var all_action_ids := Database.get_actions_all().keys()
	var locked_actions: Array[SceneAction] = []
	
	for a_id in all_action_ids:
		if ActionManager._blocked_actions.has(a_id):
			continue
		if a_id in ActionManager._selected_action_ids:
			continue
		var a = Database.get_action(a_id) as SceneAction
		if a:
			locked_actions.append(a)
	
	# 构建完整按钮列表：选中 + 锁定
	var all_visible_actions: Array[SceneAction] = []
	all_visible_actions.append_array(selected_actions)
	all_visible_actions.append_array(locked_actions)
	
	# 记录锁定 action 的 ID 列表
	_locked_action_ids.clear()
	for la in locked_actions:
		_locked_action_ids.append(la.uuid)
	
	var children = $V.get_children()
	var target_count = all_visible_actions.size()
	var current_count = children.size()
	
	# 1. 更新已有按钮（取 min）
	for i in range(min(current_count, target_count)):
		children[i].update_action(all_visible_actions[i])
		# 更新锁定状态
		if all_visible_actions[i].uuid in _locked_action_ids:
			children[i].set_locked(all_visible_actions[i].dynamic_failed_hint)
		else:
			children[i].set_unlocked()
	
	# 2. 多余的销毁
	for i in range(target_count, current_count):
		children[i].queue_free()
	
	# 3. 不足的新建
	for i in range(current_count, target_count):
		var card = preload("res://ui/action_button.tscn").instantiate()
		card.initialize(all_visible_actions[i])
		if all_visible_actions[i].uuid in _locked_action_ids:
			card.set_locked(all_visible_actions[i].dynamic_failed_hint)
		$V.add_child(card)


## 增量刷新：只更新已有按钮的锁定状态，不新建/销毁。
## 由 request_refresh_action_locks 信号触发。
func _refresh_locks_only() -> void:
	Logging.info("SceneActionScroll: 增量刷新锁定状态")
	var children = $V.get_children()
	for child in children:
		if not child is SceneActionPanel:
			continue
		var panel := child as SceneActionPanel
		if not panel.action:
			continue
		var a_id := panel.action.uuid
		
		if a_id in _locked_action_ids:
			# 未中签 action → 始终灰化（B类叙事 + 可能的A类原因）
			panel.set_locked(panel.action.dynamic_failed_hint)
		elif not ActionManager._selected_action_ids.has(a_id):
			# 不在 selected 列表也不在 locked 列表 → 新出现的 action，可能需求变满足
			panel.set_locked(panel.action.dynamic_failed_hint)
		else:
			# 已中签 action → 根据动态失败提示判断
			if panel.action.dynamic_failed_hint.is_empty():
				panel.set_unlocked()
			else:
				panel.set_locked(panel.action.dynamic_failed_hint)


# 刷新场景化行动
func _ready():
	super._ready()
	refresh()
	TimeService.on_month_tick.connect(refresh)
	EventBus.request_refresh_action_panel.connect(refresh)
	# 🆕 监听锁定状态增量刷新
	EventBus.request_refresh_action_locks.connect(_refresh_locks_only)
