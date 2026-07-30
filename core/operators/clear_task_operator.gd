@tool
class_name ClearTaskOperator extends BaseOperator
## ClearTaskOperator — 清除当前任务树的 Operator。
##
## 调用 TaskManager.clear_task() 清除所有任务（整棵树）。
## 典型 DSL 用法（在 choice_result 中）：
##   clear_task
##
## 无参数。

func operate() -> void:
	Logging.info("ClearTaskOperator.operate: 清除当前任务树")
	TaskManager.clear_task()

	if hint.is_empty():
		return
	show_hint(hint)
