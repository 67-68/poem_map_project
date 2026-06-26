@tool
class_name FocusActionOperator extends BaseOperator

## 聚焦的行动类型枚举值列表（ENUMS.ACTION_TYPE 枚举值，如 0=BAI_YE, 1=JIAO_YOU...）
## 聚焦 = Lock 这些 action + Block 其余所有 action。
@export var action_types: Array[ENUMS.ACTION_TYPE] = []

## 聚焦持续点击次数。到期后自动解除 lock/block 并刷新行动列表。
@export var click_count: int = 1


func operate():
	if action_types.is_empty():
		Logging.warn("[FocusActionOperator] action_types 为空，无操作")
		return

	if click_count <= 0:
		Logging.err("[FocusActionOperator] click_count 无效: %d，至少需要 1 次" % click_count)
		return

	var ok := ActionManager.start_focus_session(action_types, click_count)
	if not ok:
		Logging.err("[FocusActionOperator] 启动 focus session 失败")
		return

	Logging.info("[FocusActionOperator] 🔦 聚焦启动: %d action(s), %d click(s)" % [action_types.size(), click_count])
