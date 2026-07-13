class_name RemoteActionFilterManager extends RefCounted
## 异地行动过滤管理器 — 统一「行动/子行动是否可在当前驻留地点执行」的判断逻辑
##
## 职责：
##   1. 提供静态方法判断 Action 与当前地点的匹配关系
##   2. 管理 show_remote_actions 全局状态（两个 CheckBox 双向同步）
##   3. 通过 EventBus.remote_actions_filter_changed 发射状态变更信号
##   4. 提供 push/pop snapshot 栈（驻留 picker 等需要临时自动勾选的场景）
##
## 消费方：
##   - ActionPanelManager: _rebuild_all_buttons() 中过滤父行动按钮
##   - PickerTapeAttachment: initialize() / CheckBox toggle 中过滤子行动显示
##   - SceneActionPanel: 构建 picker data 时设置 _place_mismatch meta

# ═══════════════════════════════════════════════════════
# 静态状态
# ═══════════════════════════════════════════════════════

## 当前是否显示异地行动。false = 仅显示当前地点的行动。
static var show_remote_actions: bool = false

# ═══════════════════════════════════════════════════════
# 公共静态方法 — 地点判断
# ═══════════════════════════════════════════════════════

## 获取当前玩家的驻留地点字符串（xishi / pingkangfang / huangcheng）
static func get_current_place() -> String:
	return PlayerState.stay_place


## 判断 action 是否在当前地点可用（本地行动）。
## required_place 为空 → true（无地点要求，任何地点可用）
## required_place 匹配当前 stay_place → true
## 否则 → false
static func is_action_local(action: Action, place: String = "") -> bool:
	if not action:
		Logging.warn("RemoteActionFilterManager.is_action_local: action is null, returning true")
		return true
	if place.is_empty():
		place = get_current_place()
	var req: String = action.required_place
	if req.is_empty():
		return true  # 无地点要求 = 本地可用
	return req == place


## 判断 action 是否异地行动（required_place 非空 且 不匹配当前地点）
static func is_action_remote(action: Action, place: String = "") -> bool:
	if not action:
		Logging.warn("RemoteActionFilterManager.is_action_remote: action is null, returning false")
		return false
	if place.is_empty():
		place = get_current_place()
	var req: String = action.required_place
	if req.is_empty():
		return false  # 无地点要求 = 不是异地
	return req != place


## 判断父行动是否有至少一个子行动在当前地点可用。
## 父行动无子行动 → true（没有子行动，不限制）
## 父行动有子行动 → 遍历子行动，任一 is_action_local() 返回 true → 整体返回 true
static func has_local_sub_actions(action: Action, place: String = "") -> bool:
	if not action:
		Logging.warn("RemoteActionFilterManager.has_local_sub_actions: action is null, returning true")
		return true
	if place.is_empty():
		place = get_current_place()

	# 无子行动 → 不限制
	if action.sub_actions.is_empty():
		Logging.info("RemoteActionFilterManager.has_local_sub_actions: '%s' 无子行动，返回 true" % action.name)
		return true

	# 遍历子行动
	for sub_uuid in action.sub_actions:
		if sub_uuid.is_empty():
			Logging.warn("RemoteActionFilterManager.has_local_sub_actions: sub_actions 包含空 UUID，跳过")
			continue
		var sub_action := Database.get_action(sub_uuid) as Action
		if not sub_action:
			Logging.warn("RemoteActionFilterManager.has_local_sub_actions: 子行动 '%s' 无法解析，跳过" % sub_uuid)
			continue
		if is_action_local(sub_action, place):
			Logging.info("RemoteActionFilterManager.has_local_sub_actions: '%s' 子行动 '%s' 在 '%s' 可用 → true" % [action.name, sub_action.name, place])
			return true

	Logging.info("RemoteActionFilterManager.has_local_sub_actions: '%s' 所有子行动均不在 '%s' → false" % [action.name, place])
	return false


## 判断父行动是否可以被地点过滤（即：当前地点下所有子行动都是异地的）。
## 与 has_local_sub_actions 相反：无子行动 → false；所有子行动均为异地 → true
static func is_action_fully_remote(action: Action, place: String = "") -> bool:
	if not action:
		return false
	if place.is_empty():
		place = get_current_place()
	if action.sub_actions.is_empty():
		return false  # 无子行动 = 不是"完全异地"
	return not has_local_sub_actions(action, place)


# ═══════════════════════════════════════════════════════
# Snapshot 栈 — 临时覆盖 show_remote_actions
# ═══════════════════════════════════════════════════════

## 状态快照栈。push 保存当前值，pop 还原并发射信号（如有变化）。
## 用于驻留 picker 弹出时临时自动勾选「显示异地行动」。
static var _show_remote_snapshot_stack: Array[bool] = []

## 强制设为指定值（不发射信号），保存旧值到栈顶。
## 调用方负责在操作完成后调 pop_show_remote_override() 恢复。
static func push_show_remote_override(value: bool) -> void:
	_show_remote_snapshot_stack.push_back(show_remote_actions)
	show_remote_actions = value
	Logging.info("RemoteActionFilterManager.push_show_remote_override: saved=%s → set=%s, stack_depth=%d" % [_show_remote_snapshot_stack.back(), value, _show_remote_snapshot_stack.size()])


## 弹出栈顶恢复旧值。如有变化发射 signal，无变化跳过。
static func pop_show_remote_override() -> void:
	if _show_remote_snapshot_stack.is_empty():
		Logging.err("RemoteActionFilterManager.pop_show_remote_override: 栈为空，跳过")
		return
	var restored: bool = _show_remote_snapshot_stack.pop_back()
	if show_remote_actions == restored:
		Logging.info("RemoteActionFilterManager.pop_show_remote_override: 恢复值 %s 与当前相同，跳过" % str(restored))
		return
	show_remote_actions = restored
	Logging.info("RemoteActionFilterManager.pop_show_remote_override: 恢复为 %s stack_depth=%d, 发射信号" % [restored, _show_remote_snapshot_stack.size()])
	if EventBus.has_signal("remote_actions_filter_changed"):
		EventBus.remote_actions_filter_changed.emit(restored)
	else:
		Logging.err("RemoteActionFilterManager.pop_show_remote_override: EventBus.remote_actions_filter_changed 信号不存在！")


## 清空快照栈（异常恢复用）
static func clear_snapshot_stack() -> void:
	if _show_remote_snapshot_stack.is_empty():
		return
	_show_remote_snapshot_stack.clear()
	Logging.info("RemoteActionFilterManager.clear_snapshot_stack: 栈已清空")


# ═══════════════════════════════════════════════════════
# 公共静态方法 — 状态管理
# ═══════════════════════════════════════════════════════

## 设置 show_remote_actions 状态并发射信号。
## 两个 CheckBox 均调用此方法修改全局状态。
static func set_show_remote(value: bool) -> void:
	if show_remote_actions == value:
		Logging.info("RemoteActionFilterManager.set_show_remote: 状态未变化 (%s)，跳过" % str(value))
		return
	show_remote_actions = value
	Logging.info("RemoteActionFilterManager.set_show_remote: 状态变更 → %s" % str(value))
	if EventBus.has_signal("remote_actions_filter_changed"):
		EventBus.remote_actions_filter_changed.emit(value)
		Logging.info("RemoteActionFilterManager.set_show_remote: 已发射 remote_actions_filter_changed(%s)" % str(value))
	else:
		Logging.err("RemoteActionFilterManager.set_show_remote: EventBus.remote_actions_filter_changed 信号不存在！")


## 获取当前过滤状态（供消费方在初始化/重建时读取）
static func get_show_remote() -> bool:
	return show_remote_actions
