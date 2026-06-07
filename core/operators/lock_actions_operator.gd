@tool
class_name LockActionsOperator extends BaseOperator

## 要锁定的行动类型枚举值列表（ENUMS.ACTION_TYPE 枚举值，如 0=BAI_YE, 1=JIAO_YOU...）
## 锁定后该 action 必定出现在可用列表中（除非被 BlockActionOperator 冲突解除）。
@export var action_types: Array[ENUMS.ACTION_TYPE] = []

## 锁定持续旬数。-1 = 无限期（需手动 unlock），>0 = 持续 N 旬后自动过期。
@export var xun_duration: int = -1


func operate():
	if action_types.is_empty():
		Logging.warn("[LockActionsOperator] action_types 为空，无操作")
		return

	# ── 1. 逐个锁定 ──
	var locked_ids: Array[String] = []
	for at in action_types:
		var ok := ActionManager.lock_action(at, xun_duration)
		if ok:
			locked_ids.append(ActionManager.action_type_to_id(at))
		else:
			Logging.err("[LockActionsOperator] 锁定失败，无效的 ACTION_TYPE 枚举值: %d" % at)

	if locked_ids.is_empty():
		Logging.err("[LockActionsOperator] 没有有效的行动可锁定")
		return

	# ── 2. 发射选中行动变更信号（触发 UI 刷新） ──
	var selected_actions: Array[SceneAction] = []
	for action_id in locked_ids:
		var action := Database.actions.get(action_id) as SceneAction
		if action:
			selected_actions.append(action)
	if selected_actions.size() > 0:
		EventBus.selected_actions_change.emit(selected_actions)

	# ── 3. 广播锁定信号，触发 ActionMap 按钮闪光 ──
	EventBus.locked_actions_selected.emit(selected_actions)

	Logging.info("[LockActionsOperator] 锁定完成，%d 个行动: %s" % [
		locked_ids.size(),
		", ".join(locked_ids)
	])
