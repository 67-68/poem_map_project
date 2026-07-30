@tool
class_name SetTaskOperator extends BaseOperator
## SetTaskOperator — 设置/替换任务的 Operator。
##
## 四种模式（对应 TaskManager.SetMode）：
##   - REPLACE_ROOT:       清除整棵树，新 Task 成为唯一根节点
##   - REPLACE_CURRENT:    新 Task 顶替当前活跃节点
##   - APPEND_TO_CHILDREN: 新 Task 追加到当前父节点的 children 末尾
##   - CHAIN_AFTER_PARENT: 新 Task 追加到 Root 父队列末尾
##
## 典型 DSL 用法（在 choice_result 中）：
##   set_task(task=tut_learn_poem; mode=REPLACE_ROOT)
##
## 入参：
##   task: Task 资源引用（指向 .tres 文件）或 Task 实例
##   mode: SetMode 枚举字符串（REPLACE_ROOT / REPLACE_CURRENT / APPEND_TO_CHILDREN / CHAIN_AFTER_PARENT）

## Task 资源引用（.tres 文件路径或直接引用 Task 实例）
@export var task: Resource = null

## 设置模式，使用字符串以兼容 DSL 解析。
## 可选值: "REPLACE_ROOT" / "REPLACE_CURRENT" / "APPEND_TO_CHILDREN" / "CHAIN_AFTER_PARENT"
@export var mode: String = "REPLACE_ROOT"


func operate() -> void:
	if task == null:
		Logging.err("SetTaskOperator.operate: task 为 null，跳过")
		return

	if not (task is Task):
		Logging.err("SetTaskOperator.operate: task 不是 Task 类型（实际类型: %s），跳过" % task.get_class())
		return

	var mode_enum := _parse_mode(mode)
	if mode_enum < 0:
		Logging.err("SetTaskOperator.operate: 无法解析 mode='%s'，跳过" % mode)
		return

	Logging.info("SetTaskOperator.operate: task='%s', mode=%s(%d)" % [task.name, mode, mode_enum])
	TaskManager.set_task(task as Task, mode_enum)

	if hint.is_empty():
		return
	show_hint(hint)


## 将 mode 字符串解析为 TaskManager.SetMode 枚举值。
## 返回 -1 表示解析失败。
func _parse_mode(mode_str: String) -> int:
	match mode_str.to_upper():
		"REPLACE_ROOT":
			return TaskManager.SetMode.REPLACE_ROOT
		"REPLACE_CURRENT":
			return TaskManager.SetMode.REPLACE_CURRENT
		"APPEND_TO_CHILDREN":
			return TaskManager.SetMode.APPEND_TO_CHILDREN
		"CHAIN_AFTER_PARENT":
			return TaskManager.SetMode.CHAIN_AFTER_PARENT
		_:
			Logging.err("SetTaskOperator._parse_mode: 未知 mode='%s'，合法值: REPLACE_ROOT / REPLACE_CURRENT / APPEND_TO_CHILDREN / CHAIN_AFTER_PARENT" % mode_str)
			return -1


func init(context: Dictionary) -> Dictionary:
	var ctx = context.duplicate()

	# 支持从 context 中覆盖 mode
	if ctx.has("set_task_mode"):
		mode = str(ctx["set_task_mode"])
		Logging.info("SetTaskOperator.init: mode 从 context 覆盖为 '%s'" % mode)

	# 支持从 context 中获取 task（如果 .tres 中的 task 为 null）
	if ctx.has("task_resource") and task == null:
		task = ctx["task_resource"]
		Logging.info("SetTaskOperator.init: task 从 context 获取 (%s)" % task.get_class())

	return ctx
