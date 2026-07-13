class_name ActionPanelManager extends Node
## 行动面板管理器 — 替代旧的 SceneActionScroll。
##
## 职责：
## 1. 按硬编码优先级列表在 ActionPanel/VBox 中构建按钮
## 2. Era 切换时完全重建按钮（保持幂等顺序）
## 3. 同步 ActionManager 的抽取/锁定状态到按钮视觉
## 4. 🆕 根据 RemoteActionFilterManager 过滤"至少有一个子行动在当前地点"的父行动
##
## 不负责：
## - ActionPanel ↔ EventHistory 互斥可见性（由 NarrativeOverlay 管理）
## - CheckBox「显示异地行动」的创建（由 narrative_overlay.tscn 静态定义，此处仅引用连线）

# ═══════════════════════════════════════════════════════
# 硬编码按钮优先级列表（保证 Era 切换后顺序幂等）
# ═══════════════════════════════════════════════════════
# type: "scene_action" → 从 Database 查找 SceneAction
# action_id: Database.get_action() 的 key
const ACTION_PRIORITY: Array[Dictionary] = [
	{ name = "Fangshi", type = "scene_action", action_id = "fang_shi" },
	{ name = "Baiye",   type = "scene_action", action_id = "bai_ye" },
	{ name = "Jiaoyou", type = "scene_action", action_id = "jiao_you" },
	{ name = "Denggao", type = "scene_action", action_id = "deng_gao" },
	{ name = "Duzhuo",  type = "scene_action", action_id = "du_zhuo" },
	{ name = "Commute", type = "scene_action", action_id = "zhu_liu" },
]

# ── 子节点 ─────────────────────────────────────────
@onready var _narrative_overlay: NarrativeOverlay = get_parent() as NarrativeOverlay
@onready var _container: VBoxContainer = _narrative_overlay.get_node("TapeContainer/VBox/ActionPanel/V")
## 🆕 tscn 中已有的 CheckBox「显示异地行动」（V 容器内，在 "行动" Label 之后、SceneActionPanel 按钮之前）
@onready var _filter_checkbox: CheckBox = _container.get_node("CheckBox")

# ── 运行时状态 ─────────────────────────────────────
## 缓存每个按钮的锁状态实现增量 diff
var _panel_lock_cache: Dictionary = {}

# ═══════════════════════════════════════════════════════
# _ready
# ═══════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 🆕 连线 tscn 已有的 CheckBox + 同步初始勾选态
	_filter_checkbox.button_pressed = RemoteActionFilterManager.get_show_remote()
	_filter_checkbox.toggled.connect(_on_filter_checkbox_toggled)
	Logging.info("ActionPanelManager._ready: CheckBox 已连线, pressed=%s" % str(_filter_checkbox.button_pressed))

	_connect_signals()
	_rebuild_all_buttons()


# ═══════════════════════════════════════════════════════
# 信号接线
# ═══════════════════════════════════════════════════════

func _connect_signals() -> void:
	# ── 旬初重抽 ──
	if TimeService.has_signal("on_xun_tick") and not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)

	# ── 事件链结束 / Focus 结束恢复 ──
	if not EventBus.request_refresh_action_panel.is_connected(_on_refresh_panel):
		EventBus.request_refresh_action_panel.connect(_on_refresh_panel)

	# ── 属性变动增量更新锁 ──
	if not EventBus.request_refresh_action_locks.is_connected(_on_refresh_locks_only):
		EventBus.request_refresh_action_locks.connect(_on_refresh_locks_only)

	# ── Era 切换 → 完全重建 ──
	if not EventBus.era_changed.is_connected(_rebuild_all_buttons):
		EventBus.era_changed.connect(_rebuild_all_buttons)

	# 🆕 异地行动过滤状态变更 → 同步 CheckBox 勾选态 + 完全重建按钮
	if not EventBus.remote_actions_filter_changed.is_connected(_on_remote_filter_changed):
		EventBus.remote_actions_filter_changed.connect(_on_remote_filter_changed)

	# 🆕 驻留地点变更 → 完全重建按钮（切换地点后需要重新过滤）
	if not PlayerState.stay_place_changed.is_connected(_on_stay_place_changed):
		PlayerState.stay_place_changed.connect(_on_stay_place_changed)

	Logging.info("ActionPanelManager: 信号接线完成")


# ═══════════════════════════════════════════════════════
# 按钮生命周期
# ═══════════════════════════════════════════════════════

## 完全重建所有按钮（Era 切换 / 初始化时调用）。
## 保证每个按钮在多次重建后顺序与 ACTION_PRIORITY 一致。
## 🆕 根据 RemoteActionFilterManager 过滤：默认只显示"至少有一个子行动在当前地点"的父行动。
func _rebuild_all_buttons(_era: String = "") -> void:
	Logging.info("ActionPanelManager: 完全重建按钮 (era='%s')" % _era)

	# 1. 清空容器
	_clear_container()

	# 2. 遍历优先级列表
	var current_place := RemoteActionFilterManager.get_current_place()
	var show_remote := RemoteActionFilterManager.get_show_remote()
	for entry in ACTION_PRIORITY:
		var name: String = entry.get("name", "")
		var type: String = entry.get("type", "")
		var action_id: String = entry.get("action_id", "")

		match type:
			"scene_action":
				var action := Database.get_action(action_id) as Action
				if not action:
					Logging.warn("ActionPanelManager: Database 中未找到 action_id='%s' (name='%s')，跳过" % [action_id, name])
					continue
				# Era 过滤
				if not ActionManager.is_action_era_allowed(action):
					Logging.info("ActionPanelManager: action '%s' (id='%s') 被 Era 过滤，跳过" % [name, action_id])
					continue
				# 🆕 地点过滤：未勾选「显示异地」时，只显示有本地子行动的父行动
				if not show_remote:
					if not RemoteActionFilterManager.has_local_sub_actions(action, current_place):
						Logging.info("ActionPanelManager: action '%s' 所有子行动均不在 '%s'，过滤跳过" % [name, current_place])
						continue
				_create_scene_action_button(name, action_id)

			_:
				Logging.warn("ActionPanelManager: 未知按钮类型 '%s' (name=%s)" % [type, name])

	# 3. 清空锁缓存 + 刷新锁定态
	_panel_lock_cache.clear()
	_on_refresh_locks_only()

	Logging.info("ActionPanelManager: 重建完成，共 %d 个按钮" % _container.get_child_count())


## 清空 ActionPanel/V 下所有动态创建的按钮节点
## 🆕 CheckBox 不是 SceneActionPanel，不会被清除
func _clear_container() -> void:
	for child in _container.get_children():
		if child is SceneActionPanel:
			child.queue_free()


## 创建 SceneAction 按钮（受 Era 过滤）
func _create_scene_action_button(name: String, action_id: String) -> void:
	var action := Database.get_action(action_id) as SceneAction
	if not action:
		Logging.warn("ActionPanelManager: Database 中未找到 action_id='%s' (name='%s')，跳过" % [action_id, name])
		return

	# Era 过滤
	if not ActionManager.is_action_era_allowed(action):
		Logging.info("ActionPanelManager: action '%s' (id='%s') 被 Era 过滤，跳过" % [name, action_id])
		return

	var btn := preload("res://ui/action_button.tscn").instantiate()
	btn.initialize(action)
	_container.add_child(btn)
	Logging.info("ActionPanelManager: 按钮 '%s' (id='%s') 已创建" % [name, action_id])


# ═══════════════════════════════════════════════════════
# 锁定状态同步
# ═══════════════════════════════════════════════════════

## 旬初回调：全量刷新（重新抽取 + 重建 UI）
func _on_xun_tick() -> void:
	Logging.info("ActionPanelManager: 旬初触发全量刷新")
	_rebuild_all_buttons()

## 事件链 / Focus 结束回调：保留抽取结果，仅刷新锁定态
func _on_refresh_panel() -> void:
	Logging.info("ActionPanelManager: 刷新面板（不重抽）")
	_on_refresh_locks_only()

## 增量更新锁定状态（属性变动后由 ActionManager.reevaluate_all_locks 发射信号触发）
## 使用 _panel_lock_cache 做差分更新，避免无意义的 HoverPopup 注册/注销风暴
func _on_refresh_locks_only() -> void:
	Logging.debug("ActionPanelManager: 增量刷新锁定状态")
	var children := _container.get_children()
	var changed_count := 0

	for child in children:
		if not child is SceneActionPanel:
			continue
		var panel := child as SceneActionPanel

		# ── SceneAction 按钮 ──
		var a_id := panel.action.uuid
		var deferring_id := _resolve_deferring_id(panel.action)

		# 优先检查 deferring 状态（父 action 自身或其子 action 有 deferring）
		if not deferring_id.is_empty():
			changed_count += 1
			if ActionManager.is_defer_failing(deferring_id):
				panel.set_defer_failing()
			else:
				panel.set_deferring()
			_panel_lock_cache[str(panel.get_instance_id())] = {"locked": true, "deferring": true, "deferring_id": deferring_id}
			continue

		# 确定目标锁定状态
		var should_lock := false
		var lock_reason := ""

		if panel.action._is_hidden:
			should_lock = true
			lock_reason = panel.action.dynamic_failed_hint
		elif not panel.action.dynamic_failed_hint.is_empty():
			should_lock = true
			lock_reason = panel.action.dynamic_failed_hint
		elif panel.action.success_hint:
			should_lock = false

		# 差分：只在实际变化时操作
		var panel_key := str(panel.get_instance_id())
		var cached = _panel_lock_cache.get(panel_key, {})
		var cached_locked: bool = cached.get("locked", not should_lock)

		if should_lock != cached_locked or cached.get("reason", "") != lock_reason:
			changed_count += 1
			if should_lock:
				panel.set_locked(lock_reason)
			else:
				panel.set_unlocked()
			_panel_lock_cache[panel_key] = {"locked": should_lock, "reason": lock_reason}
	if changed_count > 0:
		Logging.info("ActionPanelManager: 增量刷新完成，实际锁定态变化 %d 个按钮" % changed_count)



## 解析父 action 的 deferring 状态：若自身在 deferring → 返回自身 id；
## 否则遍历 sub_actions，返回第一个 deferring 的子 action id。
## 全不匹配返回空串。
func _resolve_deferring_id(action: Action) -> String:
	if ActionManager.is_deferring(action.uuid):
		return action.uuid
	for sub_uuid in action.sub_actions:
		if ActionManager.is_deferring(sub_uuid):
			return sub_uuid
	return ""


# ═══════════════════════════════════════════════════════
# 🆕 异地行动过滤 CheckBox 信号回调
# ═══════════════════════════════════════════════════════

## tscn 中 CheckBox toggle 回调 → 同步到 RemoteActionFilterManager
func _on_filter_checkbox_toggled(toggled_on: bool) -> void:
	Logging.info("ActionPanelManager._on_filter_checkbox_toggled: toggled_on=%s" % str(toggled_on))
	RemoteActionFilterManager.set_show_remote(toggled_on)


## 🆕 异地行动过滤状态变更回调（Picker CheckBox 触发时同步本侧 CheckBox + 重建按钮）
func _on_remote_filter_changed(show: bool) -> void:
	Logging.info("ActionPanelManager._on_remote_filter_changed: show=%s" % str(show))
	if _filter_checkbox and _filter_checkbox.button_pressed != show:
		_filter_checkbox.set_pressed_no_signal(show)
		Logging.info("ActionPanelManager._on_remote_filter_changed: CheckBox 已同步为 %s" % str(show))
	_rebuild_all_buttons()


## 🆕 驻留地点变更回调 → 完全重建按钮（重新按新地点过滤）
func _on_stay_place_changed(_place_str: String) -> void:
	Logging.info("ActionPanelManager._on_stay_place_changed: place='%s', 触发重建" % _place_str)
	_rebuild_all_buttons()
