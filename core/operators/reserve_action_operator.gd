@tool
class_name ReserveActionOperator extends BaseOperator

## 要即时预留的行动 ID 列表（action_id 字符串，如 "bai_ye", "jiao_you"）。
## 预留后这些行动本回合必定出现在 6 格行动面板中。
## 注意：这是纯本回合生效，抽取后自动清空，不锁定 UI，不持久化。
@export var action_ids: PackedStringArray = PackedStringArray()


func operate():
	if action_ids.is_empty():
		Logging.warn("[ReserveActionOperator] action_ids 为空，无操作")
		return

	# ── 1. 逐个预留 ──
	var success_count := 0
	for action_id in action_ids:
		var ok := ActionManager.reserve_action(action_id)
		if ok:
			success_count += 1
		else:
			Logging.err("[ReserveActionOperator] 预留失败: %s（席位已满或重复预定）" % action_id)

	if success_count == 0:
		Logging.err("[ReserveActionOperator] 没有预留成功任何行动")
		return

	# ── 2. 发射刷新信号，让 UI 反映变化 ──
	EventBus.request_refresh_action_panel.emit()

	Logging.info("[ReserveActionOperator] 预留完成，%d/%d 个行动成功: %s" % [
		success_count,
		action_ids.size(),
		", ".join(action_ids)
	])


# ─── 契约方法 ───

func get_referenced_flags() -> Array:
	return []

func get_provided_flags() -> Array:
	return []

func get_demanded_flags() -> Array:
	return []

func get_referenced_traits() -> Array:
	return []

func get_provided_traits() -> Array:
	return []

func get_demanded_traits() -> Array:
	return []
