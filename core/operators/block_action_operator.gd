@tool
class_name BlockActionOperator extends BaseOperator

## 要阻塞的行动类型枚举值列表（ENUMS.ACTION_TYPE 枚举值，如 0=BAI_YE, 1=JIAO_YOU...）
## 阻塞后该 action 不会出现在可用列表中（除非被 LockActionsOperator 冲突解除）。
@export var action_types: Array[ENUMS.ACTION_TYPE] = []

## 阻塞持续旬数。-1 = 无限期（需手动 unblock），>0 = 持续 N 旬后自动过期。
@export var xun_duration: int = -1


func operate():
	if action_types.is_empty():
		Logging.warn("[BlockActionOperator] action_types 为空，无操作")
		return

	# ── 1. 逐个阻塞 ──
	var blocked_ids: Array[String] = []
	for at in action_types:
		var ok := ActionManager.block_action(at, xun_duration)
		if ok:
			blocked_ids.append(ActionManager.action_type_to_id(at))
		else:
			Logging.err("[BlockActionOperator] 阻塞失败，无效的 ACTION_TYPE 枚举值: %d" % at)

	if blocked_ids.is_empty():
		Logging.err("[BlockActionOperator] 没有有效的行动可阻塞")
		return

	# ── 2. 发射选中行动变更信号（触发 UI 刷新，移除被阻塞的行动） ──
	# 通知 UI 重新获取可用行动列表
	EventBus.selected_actions_change.emit([])

	Logging.info("[BlockActionOperator] 阻塞完成，%d 个行动: %s" % [
		blocked_ids.size(),
		", ".join(blocked_ids)
	])
