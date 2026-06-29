class_name ActionFocusController extends RefCounted
## 局部化 FocusSession 逻辑 — 不再污染 _blocked_actions / _locked_in_actions。
##
## 对 ActionManager 提供一个「视角（view）」而非「修改全局状态」。
## 通过接口方法向 ActionManager 报告哪些行动应被阻塞/强制入选。
##
## 生命周期：start_focus() → notify_click() × N → 自动 end_focus()。

## 聚焦行动 ID 列表
var _focus_action_ids: Array[String] = []

## 剩余点击次数
var _focus_click_remaining: int = 0


## 启动 focus session。
## focus_types: ENUMS.ACTION_TYPE 枚举值列表。
## click_count: 点击次数，归零后自动结束。
func start_focus(focus_types: Array, click_count: int) -> bool:
	if focus_types.is_empty() or click_count <= 0:
		Logging.err("[ActionFocusController] start_focus: 参数无效 (focus=%d, click=%d)" % [focus_types.size(), click_count])
		return false

	# 1. 计算聚焦 action_id 集合
	var focus_ids: Array[String] = []
	for at in focus_types:
		var id := ActionManager.action_type_to_id(at)
		if not id.is_empty() and id not in focus_ids:
			focus_ids.append(id)

	# 2. 记录状态
	_focus_action_ids = focus_ids.duplicate()
	_focus_click_remaining = click_count

	# 3. 发射 UI 信号（selected_actions_change 为 SceneActionScroll 提供渲染数据）
	var selected_actions: Array[SceneAction] = []
	for action_id in focus_ids:
		var action := Database.get_action(action_id) as SceneAction
		if action:
			selected_actions.append(action)
	if selected_actions.size() > 0:
		EventBus.selected_actions_change.emit(selected_actions)
	EventBus.locked_actions_selected.emit(selected_actions)
	EventBus.focus_session_changed.emit(true)

	Logging.info("[ActionFocusController] 🔦 启动: focus=%s, click_remaining=%d" % [", ".join(focus_ids), click_count])
	return true


## 每次行动点击后调用。递减计数器，归零时自动结束。
func notify_click() -> void:
	if _focus_click_remaining <= 0:
		return
	_focus_click_remaining -= 1
	Logging.info("[ActionFocusController] 🔦 click: remaining=%d" % _focus_click_remaining)
	if _focus_click_remaining <= 0:
		end_focus()


## 强制结束 focus session。
func end_focus() -> void:
	if _focus_action_ids.is_empty():
		return

	Logging.info("[ActionFocusController] 🔓 结束")

	_focus_action_ids.clear()
	_focus_click_remaining = 0

	EventBus.focus_session_changed.emit(false)
	EventBus.request_refresh_action_panel.emit()


# ── 查询接口 ──

## 当前是否处于 focus session 中。
func is_active() -> bool:
	return _focus_click_remaining > 0

## 返回当前聚焦的 action ID 列表。
func get_focus_ids() -> Array[String]:
	return _focus_action_ids.duplicate()

## 返回在 focus session 期间应被阻塞的 action ID 列表（= 所有非聚焦 action）。
## 由 ActionManager 在 get_available_scene_actions 中调用。
func get_block_override_ids(all_action_ids: Array) -> Array:
	if not is_active():
		return []
	var blocked: Array[String] = []
	for a_id in all_action_ids:
		if a_id not in _focus_action_ids:
			blocked.append(a_id)
	return blocked

## 返回剩余点击次数。不在 session 中返回 -1。
func get_focus_click_remaining() -> int:
	if _focus_click_remaining <= 0:
		return -1
	return _focus_click_remaining
