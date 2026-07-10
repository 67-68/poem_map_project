class_name ActionPanelManager extends Node
## 行动面板管理器 — 替代旧的 SceneActionScroll。
##
## 职责：
## 1. 按硬编码优先级列表在 ActionPanel/VBox 中构建按钮
## 2. Era 切换时完全重建按钮（保持幂等顺序）
## 3. 同步 ActionManager 的抽取/锁定状态到按钮视觉
## 4. 管理 Poem（琢句）特殊按钮的生命周期
##
## 不负责：
## - ActionPanel ↔ EventHistory 互斥可见性（由 NarrativeOverlay 管理）

# ═══════════════════════════════════════════════════════
# 硬编码按钮优先级列表（保证 Era 切换后顺序幂等）
# ═══════════════════════════════════════════════════════
# type: "special" → 特殊按钮（琢句），不受 Era 过滤
#       "scene_action" → 从 Database 查找 SceneAction
# action_id: Database.get_action() 的 key，空 = 特殊按钮
const ACTION_PRIORITY: Array[Dictionary] = [
	{ name = "Poem",    type = "special",      action_id = "" },
	{ name = "Fangshi", type = "scene_action", action_id = "fang_shi" },
	{ name = "Baiye",   type = "scene_action", action_id = "bai_ye" },
	{ name = "Jiaoyou", type = "scene_action", action_id = "jiao_you" },
	{ name = "Denggao", type = "scene_action", action_id = "deng_gao" },
	{ name = "Duzhuo",  type = "scene_action", action_id = "du_zhuo" },
	{ name = "Commute", type = "scene_action", action_id = "zhu_liu" },
]

# ── Poem 按钮常量 ──────────────────────────────────
const POEM_TITLE: String = "琢句"
const POEM_OUTCOME: String = "铺陈笔墨，直抒胸臆。"
const POEM_ICON_PATH: String = "res://assets/stamps/chuangzuo_stamp.png"

# ── 子节点 ─────────────────────────────────────────
@onready var _narrative_overlay: NarrativeOverlay = get_parent() as NarrativeOverlay
@onready var _container: VBoxContainer = _narrative_overlay.get_node("TapeContainer/VBox/ActionPanel/V")
@onready var _poem_icon: Texture2D = load(POEM_ICON_PATH)

# ── 运行时状态 ─────────────────────────────────────
## 缓存每个按钮的锁状态实现增量 diff
var _panel_lock_cache: Dictionary = {}
## Focus session 中诗按钮是否隐藏
var _poem_hidden_by_focus: bool = false

# ═══════════════════════════════════════════════════════
# _ready
# ═══════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
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

	# ── Focus session 切换 ──
	if not EventBus.focus_session_changed.is_connected(_on_focus_changed):
		EventBus.focus_session_changed.connect(_on_focus_changed)

	# ── Era 切换 → 完全重建 ──
	if not EventBus.era_changed.is_connected(_rebuild_all_buttons):
		EventBus.era_changed.connect(_rebuild_all_buttons)

	Logging.info("ActionPanelManager: 信号接线完成")


# ═══════════════════════════════════════════════════════
# 按钮生命周期
# ═══════════════════════════════════════════════════════

## 完全重建所有按钮（Era 切换 / 初始化时调用）。
## 保证每个按钮在多次重建后顺序与 ACTION_PRIORITY 一致。
func _rebuild_all_buttons(_era: String = "") -> void:
	Logging.info("ActionPanelManager: 完全重建按钮 (era='%s')" % _era)

	# 1. 清空容器
	_clear_container()

	# 2. 遍历优先级列表
	for entry in ACTION_PRIORITY:
		var name: String = entry.get("name", "")
		var type: String = entry.get("type", "")
		var action_id: String = entry.get("action_id", "")

		match type:
			"special":
				if name == "Poem":
					_create_poem_button()
				else:
					Logging.warn("ActionPanelManager: 未知 special 类型 '%s'" % name)

			"scene_action":
				_create_scene_action_button(name, action_id)

			_:
				Logging.warn("ActionPanelManager: 未知按钮类型 '%s' (name=%s)" % [type, name])

	# 3. 清空锁缓存 + 刷新锁定态
	_panel_lock_cache.clear()
	_on_refresh_locks_only()

	Logging.info("ActionPanelManager: 重建完成，共 %d 个按钮" % _container.get_child_count())


## 清空 ActionPanel/V 下所有动态创建的按钮节点
## 保留静态 Label（"行动" 标题）不删除
func _clear_container() -> void:
	for child in _container.get_children():
		if child is SceneActionPanel:
			child.queue_free()


## 创建琢句特殊按钮（不受 Era 过滤）
func _create_poem_button() -> void:
	var btn := preload("res://ui/action_button.tscn").instantiate()
	_container.add_child(btn)

	# 🚨 使用 get_node 路径访问子节点（@onready 变量在 add_child 后尚未初始化）
	var title_label: Label = btn.get_node("Panel/HBoxContainer/VBoxContainer/Title")
	var outcome_label: Label = btn.get_node("Panel/HBoxContainer/VBoxContainer/Outcome")
	var icon_rect: TextureRect = btn.get_node("Panel/HBoxContainer/TextureRect")
	title_label.text = POEM_TITLE
	outcome_label.text = POEM_OUTCOME
	icon_rect.texture = _poem_icon
	icon_rect.visible = true

	# 琢句按钮点击 → 发射诗词创建信号，不走 Action 系统
	btn.pressed.connect(func():
		EventBus.poem_start_clicked.emit()
	)

	# 不与 Action 绑定 → hover popup 可用但无内容（与旧版一致）
	Logging.info("ActionPanelManager: Poem 按钮已创建")


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

		# ── Poem 按钮（无 Action）特殊处理 ──
		if not panel.action:
			# Poem 按钮仅受 focus session 影响
			var should_lock := _poem_hidden_by_focus
			var panel_key := str(panel.get_instance_id())
			var cached = _panel_lock_cache.get(panel_key, {})
			var cached_locked: bool = cached.get("locked", not should_lock)

			if should_lock != cached_locked:
				changed_count += 1
				if should_lock:
					panel.set_locked("聚焦模式中")
				else:
					panel.set_unlocked()
				_panel_lock_cache[panel_key] = {"locked": should_lock, "reason": "" if not should_lock else "聚焦模式中"}
			continue

		# ── SceneAction 按钮 ──
		var a_id := panel.action.uuid

		# 优先检查 deferring 状态
		if ActionManager.is_deferring(a_id):
			changed_count += 1
			if ActionManager.is_defer_failing(a_id):
				panel.set_defer_failing()
			else:
				panel.set_deferring()
			_panel_lock_cache[str(panel.get_instance_id())] = {"locked": true, "deferring": true}
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


## Focus session 切换处理
func _on_focus_changed(active: bool) -> void:
	_poem_hidden_by_focus = active

	# Poem 按钮在 focus 时隐藏
	for child in _container.get_children():
		if not child is SceneActionPanel:
			continue
		var panel := child as SceneActionPanel
		if not panel.action:
			# 这是 Poem 按钮
			panel.visible = not active

	# 非 Poem 按钮由 ActionManager 的 focus override 机制通过 _on_refresh_locks_only 同步
	_on_refresh_locks_only()
