@tool
class_name Task extends GameEntity
## Task — 基于守卫条件 + 完成奖励的任务数据模型。
##
## 继承 GameEntity（uuid, name, description, icon, owner_uuids, tags, ui_decl）。
## 任务树结构（2 层实际限制，理论支持 N 层）：
##   Root（虚拟，不存在）
##    ├─ ParentA ──chain_next──→ ParentB ──chain_next──→ ParentC
##    │    ├─ Child1
##    │    └─ Child2
##
## 生命周期：INACTIVE → ACTIVE → COMPLETED
##  - 父任务激活时，其所有子任务自动激活。
##  - 子任务全部完成 + 自身 requirements 通过 → 执行 operators → COMPLETED。
##  - 一次性：完成后不再检测。

enum TaskStatus {
	INACTIVE = 0,
	ACTIVE = 1,
	COMPLETED = 2,
}

## 守卫条件列表（全部 AND 逻辑）。全部通过 + 子任务全完成 → 此任务完成。
@export var requirements: Array[BaseRequirements] = []

## 完成后执行的奖励操作符（顺序执行）。
@export var operators: Array[BaseOperator] = []

## 标记为手动任务：即使 requirements 为空也不会在 _check_and_advance 中自动完成。
## 必须由外部调用 TaskManager.complete_current_task() 显式完成。
## 典型场景：无实际条件的"展示性"任务（如"登顶"线索）。
@export var is_manual_complete: bool = false

## ── 以下字段为运行时状态，不由 .tres 序列化 ──

## 父任务引用（null 表示是 Root 的直接子任务 / 父队列成员）。
var parent: Task = null

## 子任务列表（必须在父任务完成之前全部完成）。
var children: Array[Task] = []

## 父队列链表：当前父任务完成后激活的下一个父任务。
## 仅对父级任务有意义；子任务的 chain_next 无效。
var chain_next: Task = null

## 当前状态。由 TaskManager 管理，不由 .tres 设置。
var status: int = TaskStatus.INACTIVE


## 状态可读名称（调试用）
func status_name() -> String:
	match status:
		TaskStatus.INACTIVE: return "INACTIVE"
		TaskStatus.ACTIVE: return "ACTIVE"
		TaskStatus.COMPLETED: return "COMPLETED"
		_: return "UNKNOWN(%d)" % status


## 是否为叶子节点（无子任务）
func is_leaf() -> bool:
	return children.is_empty()


## 是否所有子任务已完成
func all_children_completed() -> bool:
	for child in children:
		if child.status != TaskStatus.COMPLETED:
			return false
	return true


## 判断所有守卫条件是否通过。
## is_manual_complete 任务永远返回 false（不允许自动完成）。
func all_requirements_met(player_state) -> bool:
	if is_manual_complete:
		Logging.info("TaskManager: Task '%s' 是手动任务 (is_manual_complete)，自动扫描跳过" % name)
		return false
	if requirements.is_empty():
		Logging.info("TaskManager: Task '%s' 无 requirements，默认通过" % name)
		return true
	for i in range(requirements.size()):
		var req = requirements[i]
		if not req:
			Logging.err("TaskManager: Task '%s' requirements[%d] 为 null，跳过" % [name, i])
			continue
		if not req.compare(player_state):
			Logging.info("TaskManager: Task '%s' requirement[%d] (%s) 未通过 — hint: %s" % [name, i, req.get_class(), req.get_failed_hint()])
			return false
	Logging.info("TaskManager: Task '%s' 全部 %d 个 requirements 通过" % [name, requirements.size()])
	return true
