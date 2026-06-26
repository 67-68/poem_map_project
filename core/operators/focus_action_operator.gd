@tool
class_name FocusActionOperator extends BaseOperator

## 聚焦的行动类型枚举值列表（ENUMS.ACTION_TYPE 枚举值，如 0=BAI_YE, 1=JIAO_YOU...）
## 聚焦 = Lock 这些 action + Block 其余所有 action。
@export var action_types: Array[ENUMS.ACTION_TYPE] = []

## 聚焦持续旬数。-1 = 无限期，>0 = 持续 N 旬后自动过期。
@export var xun_duration: int = -1


func operate():
	if action_types.is_empty():
		Logging.warn("[FocusActionOperator] action_types 为空，无操作")
		return

	# ── 1. 计算非聚焦的 action 集合（others = 全部 - focus） ──
	var focus_set: Array[ENUMS.ACTION_TYPE] = []
	for at in action_types:
		if at >= 0 and at < ENUMS.ACTION_TYPE.size():
			if at not in focus_set:
				focus_set.append(at)

	var others: Array[ENUMS.ACTION_TYPE] = []
	for i in ENUMS.ACTION_TYPE.values():
		if i not in focus_set:
			others.append(i)

	# ── 2. 先 Block 所有非聚焦的 action（先 block，后 lock 才能冲突解除） ──
	var blocked_ids: Array[String] = []
	for at in others:
		var ok := ActionManager.block_action(at, xun_duration)
		if ok:
			blocked_ids.append(ActionManager.action_type_to_id(at))
		else:
			Logging.err("[FocusActionOperator] Block 失败，无效的 ACTION_TYPE 枚举值: %d" % at)

	# ── 3. 再 Lock 聚焦的 action（后调用者赢，自动解除上一步的 block） ──
	var locked_ids: Array[String] = []
	for at in focus_set:
		var ok := ActionManager.lock_action(at, xun_duration)
		if ok:
			locked_ids.append(ActionManager.action_type_to_id(at))
		else:
			Logging.err("[FocusActionOperator] Lock 失败，无效的 ACTION_TYPE 枚举值: %d" % at)

	if locked_ids.is_empty():
		Logging.err("[FocusActionOperator] 没有有效的 action 可聚焦")
		return

	# ── 4. 发射选中行动变更信号（触发 UI 刷新） ──
	var selected_actions: Array[SceneAction] = []
	for action_id in locked_ids:
		var action := Database.get_action(action_id) as SceneAction
		if action:
			selected_actions.append(action)
	if selected_actions.size() > 0:
		EventBus.selected_actions_change.emit(selected_actions)

	# ── 5. 广播锁定信号，触发 ActionMap 按钮闪光 ──
	EventBus.locked_actions_selected.emit(selected_actions)

	Logging.info("[FocusActionOperator] 聚焦完成，锁定 %d 个 + 阻塞 %d 个 (持续 %d 旬)" % [
		locked_ids.size(),
		blocked_ids.size(),
		xun_duration
	])
