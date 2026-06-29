class_name SceneActionScroll extends SmoothScrollContainer

var _locked_action_ids: Array[String] = []  # 当前灰化显示的 action ID 列表

func refresh():
	"""
	三阶段管道刷新 scene action：
	1. pick_top_actions — 从全池抽选
	2. apply_visibility_flags — 设隐藏/锁定标志位
	3. 按标志位渲染（_is_hidden 跳过，dynamic_failed_hint 决定亮/灰）
	"""
	Logging.debug("[SceneActionScroll] refresh() 被调用")
	
	# Phase 1: 抽取
	var pool = ActionManager.get_available_scene_actions()
	var selected_actions = ActionManager.pick_top_actions(pool)
	EventBus.selected_actions_change.emit(selected_actions)
	
	# Phase 2+3: 设置隐藏/锁定标志位
	ActionManager.apply_visibility_flags()
	
	# 按标志位构建显示列表
	var all_visible_actions: Array[SceneAction] = []
	var _new_locked_ids: Array[String] = []
	
	for a_id in Database.get_actions_all():
		var a = Database.get_action(a_id) as SceneAction
		if not a or a._is_hidden:
			continue
		all_visible_actions.append(a)
		if a_id not in ActionManager._selected_action_ids:
			_new_locked_ids.append(a.uuid)
	
	# 差分更新
	var children = $V.get_children()
	var target_count = all_visible_actions.size()
	var current_count = children.size()
	
	for i in range(min(current_count, target_count)):
		children[i].update_action(all_visible_actions[i])
		if all_visible_actions[i].uuid in _new_locked_ids or not all_visible_actions[i].dynamic_failed_hint.is_empty():
			children[i].set_locked(all_visible_actions[i].dynamic_failed_hint)
		else:
			children[i].set_unlocked()
	
	for i in range(target_count, current_count):
		children[i].queue_free()
	
	for i in range(current_count, target_count):
		var card = preload("res://ui/action_button.tscn").instantiate()
		card.initialize(all_visible_actions[i])
		if all_visible_actions[i].uuid in _new_locked_ids or not all_visible_actions[i].dynamic_failed_hint.is_empty():
			card.set_locked(all_visible_actions[i].dynamic_failed_hint)
		$V.add_child(card)
	
	_locked_action_ids = _new_locked_ids


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
	TimeService.on_xun_tick.connect(refresh)
	EventBus.request_refresh_action_panel.connect(refresh)
	# 🆕 监听锁定状态增量刷新
	EventBus.request_refresh_action_locks.connect(_refresh_locks_only)
