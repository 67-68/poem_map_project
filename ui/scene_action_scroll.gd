class_name SceneActionScroll extends SmoothScrollContainer

var _locked_action_ids: Array[String] = []  # 当前灰化显示的 action ID 列表

## 缓存每个面板的锁状态，实现增量 diff：只有状态真正变化时才调用 set_locked/set_unlocked
## key: panel instance_id(str), value: { "locked": bool, "reason": String }
var _panel_lock_cache: Dictionary = {}

func refresh(repick: bool = true):
	"""
	三阶段管道刷新 scene action：
	1. pick_top_actions — 从全池抽选（仅 repick=true 时，默认每旬初）
	2. apply_visibility_flags — 设隐藏/锁定标志位
	3. 按标志位渲染（_is_hidden 跳过，dynamic_failed_hint 决定亮/灰）
	
	repick=false 用于事件结束/Focus结束等场景：保留现有 _selected_action_ids，
	仅重建 UI 布局和刷新灰化状态，不重新随机抽签。
	"""
	Logging.info("[SceneActionScroll] refresh(repick=%s) 被调用" % repick)
	
	# 全量刷新意味着按钮数据全部变化，清空增量 diff 缓存
	_panel_lock_cache.clear()
	
	# Phase 1: 抽取（仅 repick=true 时重抽）
	var pool = ActionManager.get_available_scene_actions()
	if repick:
		var selected_actions = ActionManager.pick_top_actions(pool)
		EventBus.selected_actions_change.emit(selected_actions)
		Logging.info("[SceneActionScroll] refresh: repick=true, 已重新抽签（%d 个中签）" % selected_actions.size())
	else:
		Logging.info("[SceneActionScroll] refresh: repick=false, 保留现有 _selected_action_ids（%d 个中签）" % ActionManager._selected_action_ids.size())
	
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
##
## 性能关键路径：使用 _panel_lock_cache 做差分更新，
## 只有锁定状态实际变化时才调用 set_locked/set_unlocked，
## 避免无意义的 HoverPopupManager unregister/register 风暴。
func _refresh_locks_only() -> void:
	Logging.debug("SceneActionScroll: 增量刷新锁定状态")
	var children = $V.get_children()
	var changed_count := 0
	for child in children:
		if not child is SceneActionPanel:
			continue
		var panel := child as SceneActionPanel
		if not panel.action:
			continue
		var a_id := panel.action.uuid
		
		# 确定目标锁定状态
		var should_lock := false
		var lock_reason := ""
		
		if a_id in _locked_action_ids:
			should_lock = true
			lock_reason = panel.action.dynamic_failed_hint
		elif not ActionManager._selected_action_ids.has(a_id):
			should_lock = true
			lock_reason = panel.action.dynamic_failed_hint
		else:
			if panel.action.dynamic_failed_hint.is_empty():
				should_lock = false
			else:
				should_lock = true
				lock_reason = panel.action.dynamic_failed_hint
		
		# diff：只在状态变化时操作
		var panel_key := str(panel.get_instance_id())
		var cached = _panel_lock_cache.get(panel_key, {})
		var cached_locked: bool = cached.get("locked", not should_lock)  # 用反值确保首次必定触发
		
		if should_lock != cached_locked:
			changed_count += 1
			if should_lock:
				panel.set_locked(lock_reason)
			else:
				panel.set_unlocked()
			_panel_lock_cache[panel_key] = {"locked": should_lock, "reason": lock_reason}
	
	if changed_count > 0:
		Logging.info("SceneActionScroll: 增量刷新完成，实际锁定态变化 %d 个按钮" % changed_count)


# 刷新场景化行动
func _ready():
	super._ready()
	refresh()
	TimeService.on_xun_tick.connect(refresh)  # 旬初：repick=true（默认），重新抽签
	EventBus.request_refresh_action_panel.connect(func(): refresh(false))  # 事件结束/Focus结束：repick=false，不重抽
	# 🆕 监听锁定状态增量刷新
	EventBus.request_refresh_action_locks.connect(_refresh_locks_only)

	# 🆕 事件锁：监听 NarrativeOverlay 的事件开始/结束信号
	_connect_event_lock_signals()


## 🆕 懒连接 NarrativeOverlay 的事件锁信号
func _connect_event_lock_signals() -> void:
	var tree := get_tree()
	if not tree or not tree.root:
		Logging.warn("SceneActionScroll._connect_event_lock_signals: tree not ready, retrying deferred")
		call_deferred("_connect_event_lock_signals")
		return
	var main_node := tree.root.get_node_or_null("Main")
	if not main_node:
		Logging.warn("SceneActionScroll._connect_event_lock_signals: Main node not found, retrying deferred")
		call_deferred("_connect_event_lock_signals")
		return
	var overlay := main_node.get_node_or_null("TapeLayer/NarrativeOverlay")
	if not overlay:
		Logging.warn("SceneActionScroll._connect_event_lock_signals: NarrativeOverlay not found, retrying deferred")
		call_deferred("_connect_event_lock_signals")
		return
	if overlay.has_signal("event_display_started") and not overlay.event_display_started.is_connected(_lock_all_for_event):
		overlay.event_display_started.connect(_lock_all_for_event)
		Logging.info("SceneActionScroll: connected to NarrativeOverlay.event_display_started")
	if overlay.has_signal("event_display_ended") and not overlay.event_display_ended.is_connected(_unlock_all_from_event):
		overlay.event_display_ended.connect(_unlock_all_from_event)
		Logging.info("SceneActionScroll: connected to NarrativeOverlay.event_display_ended")

## 🆕 事件开始时：锁定所有行动按钮，提示"请先完成当前事件再选择"
func _lock_all_for_event() -> void:
	Logging.info("[DIAG] SceneActionScroll._lock_all_for_event: 锁定所有行动")
	const EVENT_LOCK_REASON: String = "请先完成当前事件再选择"
	var children = $V.get_children()
	for child in children:
		if not child is SceneActionPanel:
			continue
		var panel := child as SceneActionPanel
		if not panel.action:
			continue
		# 临时覆盖 dynamic_failed_hint 并锁住
		panel.set_locked(EVENT_LOCK_REASON)
	Logging.info("[DIAG] SceneActionScroll._lock_all_for_event: 已锁定 %d 个行动" % children.size())

## 🆕 事件结束时：恢复行动按钮的正常锁定状态（repick=false，不重抽）
func _unlock_all_from_event() -> void:
	Logging.info("[DIAG] SceneActionScroll._unlock_all_from_event: 恢复行动状态（不重抽）")
	refresh(false)
