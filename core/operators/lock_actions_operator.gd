@tool
class_name LockActionsOperator extends BaseOperator

## 要锁定的行动类型枚举值列表（ENUMS.ACTION_TYPE 枚举值，如 0=BAI_YE, 1=JIAO_YOU...）
##
## 调用时：清空现有预定 → 直接从 Database.actions 拉取指定行动 →
## 发射 selected_actions_change 完成刷新，绕过正常可用性检查（地区/标签过滤）。
@export var action_types: Array[ENUMS.ACTION_TYPE] = []


func operate():
	# ── 1. 清空 ActionManager 的残留预定，避免跨回合污染 ──
	ActionManager.clear_reservations()
	Logging.info("[LockActionsOperator] 已清空现有预定")

	# ── 2. 根据传入的 enum 构建锁定行动列表 ──
	var selected_actions: Array[SceneAction] = []
	for at in action_types:
		var action_id := _action_type_to_id(at)
		if action_id.is_empty():
			Logging.err("[LockActionsOperator] 无效的 ACTION_TYPE 枚举值: %d" % at)
			continue

		var action := Database.actions.get(action_id) as SceneAction
		if action == null:
			Logging.err("[LockActionsOperator] 行动 '%s' 不存在于 Database.actions 中，跳过" % action_id)
			continue

		selected_actions.append(action)
		Logging.info("[LockActionsOperator] 锁定行动: %s" % action_id)

	if selected_actions.is_empty():
		Logging.err("[LockActionsOperator] 没有有效的行动可锁定，放弃刷新")
		return

	# ── 3. 发射选中行动变更信号（触发 UI 刷新） ──
	EventBus.selected_actions_change.emit(selected_actions)

	# ── 4. 广播锁定信号，触发 ActionMap 按钮闪光 ──
	EventBus.locked_actions_selected.emit(selected_actions)

	Logging.info("[LockActionsOperator] 刷新完成，锁定 %d 个行动: %s" % [
		selected_actions.size(),
		_str_action_ids(selected_actions)
	])


## 将 ENUMS.ACTION_TYPE 枚举值转为 action ID 字符串（如 BAI_YE → "bai_ye"）
func _action_type_to_id(enum_val: int) -> String:
	if enum_val < 0 or enum_val >= ENUMS.ACTION_TYPE.size():
		return ""
	return ENUMS.ACTION_TYPE.keys()[enum_val].to_lower()


## 从选中的 SceneAction 数组中提取 action_id 字符串用于日志
func _str_action_ids(actions: Array[SceneAction]) -> String:
	var ids: PackedStringArray = []
	for a in actions:
		var key = Database.actions.find_key(a)
		if key:
			ids.append(key)
	return ", ".join(ids)
