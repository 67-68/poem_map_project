extends Node
## TaskManager — 任务树生命周期管理器 Autoload。
##
## 职责：
##   1. 维护任务树（_root_tasks 父队列 + child 层级）。
##   2. 连接信号源（PlayerState / EventBus），属性/状态变化时自动检测守卫条件。
##   3. 守卫条件通过后执行 operators，标记 COMPLETED。
##   4. 提供 set_task() / clear_task() 接口给 Operator 调用。
##
## 层级限制：实际使用中只有 2 层（父 → 子），但代码支持 N 层。

## SetTaskOperator 的四种模式
enum SetMode {
	REPLACE_ROOT,        # 清除整棵树，新 Task 成为唯一根节点
	REPLACE_CURRENT,     # 新 Task 顶替当前活跃节点
	APPEND_TO_CHILDREN,  # 新 Task 追加到当前父节点的 children 末尾
	CHAIN_AFTER_PARENT,  # 新 Task 追加到 Root 父队列末尾
}

## 当前活跃的最深未完成任务（null = 无任务）。
## 每次状态变化后重新计算：从 root 向下遍历，优先选未完成 child。
var _current_task: Task = null

## 父任务队列（Root 的直接子任务）。顺序执行：前一个 COMPLETED → 后一个 ACTIVE。
var _root_tasks: Array[Task] = []

## uuid → Task 的全量查找表（用于从 .tres 序列化后恢复引用）。
var _task_registry: Dictionary = {}

## 最近完成的任务（供 UI 展示 TaskPrev 划掉状态）。
## 每次任务 COMPLETED 时更新。
var _last_completed_task: Task = null

## 任务树是否有变化（供 UI 检测是否需要刷新闪烁动画）。
## set_task / clear_task / 完成时设为 true，UI 消费后重置为 false。
var _state_dirty: bool = false


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_connect_signals()
	Logging.info("TaskManager: 已就绪，信号已连接")


func _connect_signals() -> void:
	# 属性变化
	if not PlayerState.player_stat_changed.is_connected(_on_state_changed):
		PlayerState.player_stat_changed.connect(_on_state_changed.bind("player_stat_changed"))
		Logging.info("TaskManager: 已连接 PlayerState.player_stat_changed")

	# 地点变化
	if not PlayerState.stay_place_changed.is_connected(_on_state_changed):
		PlayerState.stay_place_changed.connect(_on_state_changed.bind("stay_place_changed"))
		Logging.info("TaskManager: 已连接 PlayerState.stay_place_changed")

	# Trait 变化
	if not EventBus.on_trait_change.is_connected(_on_state_changed):
		EventBus.on_trait_change.connect(_on_state_changed.bind("on_trait_change"))
		Logging.info("TaskManager: 已连接 EventBus.on_trait_change")

	# Flag 变化
	if not EventBus.on_flag_change.is_connected(_on_state_changed):
		EventBus.on_flag_change.connect(_on_state_changed.bind("on_flag_change"))
		Logging.info("TaskManager: 已连接 EventBus.on_flag_change")

	# 意象变化
	if not EventBus.imaginary_changed.is_connected(_on_state_changed):
		EventBus.imaginary_changed.connect(_on_state_changed.bind("imaginary_changed"))
		Logging.info("TaskManager: 已连接 EventBus.imaginary_changed")

	# 事件结果执行完成
	if not EventBus.event_confirmed.is_connected(_on_state_changed):
		EventBus.event_confirmed.connect(_on_state_changed.bind("event_confirmed"))
		Logging.info("TaskManager: 已连接 EventBus.event_confirmed")

	# 人物关系状态变更
	if not EventBus.on_person_state_changed.is_connected(_on_state_changed):
		EventBus.on_person_state_changed.connect(_on_state_changed.bind("on_person_state_changed"))
		Logging.info("TaskManager: 已连接 EventBus.on_person_state_changed")


# ═══════════════════════════════════════════════════════════
# 公开 API — Operator 调用入口
# ═══════════════════════════════════════════════════════════

## 设置/替换任务。由 SetTaskOperator.operate() 调用。
## task: 要设置的 Task 实例。
## mode:  SetMode 枚举值。
func set_task(task: Task, mode: int) -> void:
	if not task:
		Logging.err("TaskManager.set_task: task 为 null，跳过")
		return

	Logging.info("TaskManager.set_task: task='%s' (%s), mode=%d" % [task.name, task.uuid, mode])

	match mode:
		SetMode.REPLACE_ROOT:
			_replace_root(task)
		SetMode.REPLACE_CURRENT:
			_replace_current(task)
		SetMode.APPEND_TO_CHILDREN:
			_append_to_children(task)
		SetMode.CHAIN_AFTER_PARENT:
			_chain_after_parent(task)
		_:
			Logging.err("TaskManager.set_task: 未知 mode=%d" % mode)
			return

	# 注册到查找表
	_register_task(task)

	# 刷新当前任务指针并立即检测一次
	_recalc_current()
	_check_and_advance()

	# 通知 UI 刷新
	_state_dirty = true
	EventBus.task_state_changed.emit()
	Logging.info("TaskManager.set_task: task_state_changed 已发射")


## 清除所有任务。由 ClearTaskOperator.operate() 调用。
func clear_task() -> void:
	if _root_tasks.is_empty():
		Logging.info("TaskManager.clear_task: 任务树已为空，跳过")
		return

	Logging.info("TaskManager.clear_task: 清除全部 %d 个根任务" % _root_tasks.size())
	_clear_all(_root_tasks)
	_root_tasks.clear()
	_current_task = null
	_last_completed_task = null
	_state_dirty = true
	_task_registry.clear()
	EventBus.task_state_changed.emit()
	Logging.info("TaskManager.clear_task: 任务树已清空")


## 获取当前活跃任务（供 UI 读取）。
func get_current_task() -> Task:
	return _current_task


## 获取所有根任务（供 UI 读取父队列）。
func get_root_tasks() -> Array[Task]:
	return _root_tasks


## 获取父任务（当前最深未完成任务的 parent）。
## 返回 null 表示当前任务没有父任务（是根级任务）。
func get_parent_task() -> Task:
	if _current_task == null:
		return null
	return _current_task.parent


## 获取下一个待执行任务。
## 优先：_current_task 的下一个未完成兄弟。
## 其次：chain_next 父任务。
## 都不存在 → null。
func get_next_task() -> Task:
	if _current_task == null:
		return null

	# 优先：同层下一个未完成兄弟
	if _current_task.parent != null:
		var siblings := _current_task.parent.children
		var my_idx := siblings.find(_current_task)
		if my_idx >= 0:
			for i in range(my_idx + 1, siblings.size()):
				if siblings[i].status != Task.TaskStatus.COMPLETED:
					Logging.info("TaskManager.get_next_task: 下一个兄弟 '%s'" % siblings[i].name)
					return siblings[i]
	else:
		# 当前是根级任务，找下一个未完成的根级
		var my_idx := _root_tasks.find(_current_task)
		if my_idx >= 0:
			for i in range(my_idx + 1, _root_tasks.size()):
				if _root_tasks[i].status != Task.TaskStatus.COMPLETED:
					Logging.info("TaskManager.get_next_task: 下一个根级 '%s'" % _root_tasks[i].name)
					return _root_tasks[i]

	# 其次：chain_next
	if _current_task.chain_next != null:
		Logging.info("TaskManager.get_next_task: chain_next '%s'" % _current_task.chain_next.name)
		return _current_task.chain_next

	# 如果当前是子任务，查父任务的 chain_next
	if _current_task.parent != null and _current_task.parent.chain_next != null:
		Logging.info("TaskManager.get_next_task: 父任务 chain_next '%s'" % _current_task.parent.chain_next.name)
		return _current_task.parent.chain_next

	Logging.info("TaskManager.get_next_task: 无下一个任务")
	return null


## 获取最近完成的任务（供 UI 展示 TaskPrev）。
func get_last_completed_task() -> Task:
	return _last_completed_task


## 检查任务树是否有未消费的变化（供 UI 决定是否播放闪烁动画）。
func is_state_dirty() -> bool:
	return _state_dirty


## UI 消费 dirty 标志后调用，避免重复闪烁。
func mark_state_clean() -> void:
	_state_dirty = false


## 强制完成当前最深未完成任务（绕过 is_manual_complete 和 requirements 检查）。
## 供 TutorialController 等外部回调使用。
## 调用后会自动更新 _last_completed_task 并 emit task_state_changed。
func complete_current_task() -> void:
	if _current_task == null:
		Logging.info("TaskManager.complete_current_task: 无当前任务，跳过")
		return

	var ct := _current_task
	Logging.info("TaskManager.complete_current_task: 强制完成 '%s' (is_manual_complete=%s)" % [ct.name, str(ct.is_manual_complete)])

	# 执行 operators
	_execute_operators(ct)
	ct.status = Task.TaskStatus.COMPLETED
	_last_completed_task = ct
	_state_dirty = true

	Logging.info("TaskManager: '%s' → COMPLETED (手动)" % ct.name)
	EventBus.task_completed.emit(ct)
	EventBus.task_state_changed.emit()

	# 向上递归
	if ct.parent != null:
		Logging.info("TaskManager: '%s' 有父任务 '%s'，向上传递" % [ct.name, ct.parent.name])
	else:
		_try_activate_chain_next(ct)

	_recalc_current()


# ═══════════════════════════════════════════════════════════
# SetTask 四种模式实现
# ═══════════════════════════════════════════════════════════

func _replace_root(task: Task) -> void:
	Logging.info("TaskManager: REPLACE_ROOT — 清除旧树，%s 成为新根" % task.name)
	_clear_all(_root_tasks)
	_root_tasks.clear()
	_task_registry.clear()
	task.status = Task.TaskStatus.ACTIVE
	_activate_children(task)
	_root_tasks.append(task)


func _replace_current(task: Task) -> void:
	if _current_task == null:
		Logging.info("TaskManager: REPLACE_CURRENT — 当前无任务，退化为 REPLACE_ROOT")
		_replace_root(task)
		return

	Logging.info("TaskManager: REPLACE_CURRENT — %s 顶替 %s" % [task.name, _current_task.name])

	var parent_of_current := _find_parent_in_tree(_current_task)

	if parent_of_current != null:
		# 在 parent 的 children 中替换
		var idx := parent_of_current.children.find(_current_task)
		if idx >= 0:
			# 递归清除被替换节点的子树
			_clear_all([_current_task])
			task.parent = parent_of_current
			parent_of_current.children[idx] = task
			Logging.info("TaskManager: REPLACE_CURRENT — 在 parent '%s' 的 children[%d] 替换" % [parent_of_current.name, idx])
	else:
		# 在 _root_tasks 中替换
		var idx := _root_tasks.find(_current_task)
		if idx >= 0:
			_clear_all([_current_task])
			_root_tasks[idx] = task
			Logging.info("TaskManager: REPLACE_CURRENT — 在 _root_tasks[%d] 替换" % idx)
		else:
			Logging.err("TaskManager: REPLACE_CURRENT — 在树中找不到当前任务 '%s'，退化为 REPLACE_ROOT" % _current_task.name)
			_replace_root(task)
			return

	task.status = Task.TaskStatus.ACTIVE
	_activate_children(task)


func _append_to_children(task: Task) -> void:
	# 找到当前任务的"容纳容器"：
	#   - 如果当前任务是父任务（有 children），追加到它的 children
	#   - 如果当前任务是子任务，追加到它 parent 的 children
	#   - 如果无当前任务，追加到 _root_tasks
	if _current_task == null:
		Logging.info("TaskManager: APPEND_TO_CHILDREN — 当前无任务，追加到 _root_tasks")
		task.status = Task.TaskStatus.ACTIVE
		_activate_children(task)
		_root_tasks.append(task)
		return

	var container := _resolve_append_container(_current_task)
	if container == null:
		Logging.info("TaskManager: APPEND_TO_CHILDREN — 无法确定容器，追加到 _root_tasks")
		task.status = Task.TaskStatus.ACTIVE
		_activate_children(task)
		_root_tasks.append(task)
		return

	Logging.info("TaskManager: APPEND_TO_CHILDREN — %s 追加到 '%s' 的 children" % [task.name, container.name])
	task.parent = container
	task.status = Task.TaskStatus.INACTIVE  # 等待父任务激活
	container.children.append(task)


func _chain_after_parent(task: Task) -> void:
	# 找到当前节点最近的父级祖先所在的父队列，追加到该父队列末尾。
	# 如果当前节点本身就是根节点，直接追加到 _root_tasks 末尾。
	if _current_task == null:
		Logging.info("TaskManager: CHAIN_AFTER_PARENT — 当前无任务，追加到 _root_tasks")
		task.status = Task.TaskStatus.INACTIVE
		_root_tasks.append(task)
		return

	# 沿着 parent 链向上找到根级祖先
	var ancestor := _current_task
	while ancestor.parent != null:
		ancestor = ancestor.parent

	# 找到 ancestor 在 _root_tasks 中的位置
	var idx := _root_tasks.find(ancestor)
	if idx < 0:
		Logging.err("TaskManager: CHAIN_AFTER_PARENT — 根级祖先 '%s' 不在 _root_tasks 中，追加到末尾" % ancestor.name)
		task.status = Task.TaskStatus.INACTIVE
		_root_tasks.append(task)
		return

	# 找到该父队列的最后一个节点（沿 chain_next 链走到底）
	var tail := _root_tasks[idx]
	while tail.chain_next != null:
		tail = tail.chain_next

	Logging.info("TaskManager: CHAIN_AFTER_PARENT — %s chain 到 '%s' 之后（父队列位置=%d）" % [task.name, tail.name, idx])
	tail.chain_next = task
	task.status = Task.TaskStatus.INACTIVE


# ═══════════════════════════════════════════════════════════
# 信号回调 — 守卫扫描
# ═══════════════════════════════════════════════════════════

func _on_state_changed(_signal_name: String) -> void:
	if _root_tasks.is_empty():
		return
	Logging.info("TaskManager: 收到信号 '%s'，开始守卫扫描" % _signal_name)
	_check_and_advance()


## 核心守卫扫描循环：
##   1. 重新定位当前最深未完成任务
##   2. 找到需要检测的叶子节点（所有叶子都是 ACTIVE 且 children 全完成）
##   3. 检测其 requirements
##   4. 通过 → 完成 + 向上递归
##   5. 重复直到没有新完成的任务
func _check_and_advance() -> void:
	var completed_any := false
	var max_iterations := 100  # 安全阀

	for _iter in range(max_iterations):
		_recalc_current()

		# 找到需要检测的节点：最深叶子且其所有 ancestors 下都没有未完成的兄弟
		var candidate := _find_completable_leaf()
		if candidate == null:
			Logging.info("TaskManager: _check_and_advance — 无可完成的任务候选")
			break

		Logging.info("TaskManager: _check_and_advance — 检测候选任务 '%s' (status=%s)" % [candidate.name, candidate.status_name()])

		if candidate.status != Task.TaskStatus.ACTIVE:
			Logging.info("TaskManager: _check_and_advance — '%s' 非 ACTIVE，跳过" % candidate.name)
			break

		if not candidate.all_children_completed():
			Logging.info("TaskManager: _check_and_advance — '%s' 有未完成的子任务，跳过" % candidate.name)
			break

		if not candidate.all_requirements_met(PlayerState):
			Logging.info("TaskManager: _check_and_advance — '%s' requirements 未通过，停止扫描" % candidate.name)
			break

		# 通过 — 执行奖励，标记完成
		Logging.info("TaskManager: ✅ '%s' requirements 通过，执行 %d 个 operators" % [candidate.name, candidate.operators.size()])
		_execute_operators(candidate)
		candidate.status = Task.TaskStatus.COMPLETED
		_last_completed_task = candidate
		_state_dirty = true
		Logging.info("TaskManager: '%s' → COMPLETED, _last_completed_task=%s" % [candidate.name, _last_completed_task.name])
		EventBus.task_completed.emit(candidate)
		EventBus.task_state_changed.emit()
		completed_any = true

		# 向上递归：检查 parent
		if candidate.parent != null:
			Logging.info("TaskManager: '%s' 有父任务 '%s'，标记为检测候选" % [candidate.name, candidate.parent.name])
		else:
			# 根级任务完成 → 激活 chain_next
			_try_activate_chain_next(candidate)

	Logging.info("TaskManager: _check_and_advance 完成，completed_any=%s" % str(completed_any))


## 找到需要检测的叶子节点。
## 策略：从当前任务出发，向上找其最近的未完成 parent，然后向下找第一个未完成叶子。
func _find_completable_leaf() -> Task:
	if _current_task == null:
		return null

	# 从 _current_task 向上找到第一个未完成的祖先（可能是它自己）
	var node := _current_task
	while node != null and node.status == Task.TaskStatus.COMPLETED:
		node = node.parent

	if node == null:
		Logging.info("TaskManager: _find_completable_leaf — 所有祖先已完成")
		return null

	# 从 node 向下找最深叶子
	return _find_deepest_leaf(node)


## 从给定节点出发，递归找到最深的第一个未完成叶子。
func _find_deepest_leaf(node: Task) -> Task:
	if node.status == Task.TaskStatus.COMPLETED:
		Logging.info("TaskManager: _find_deepest_leaf — '%s' 已完成，返回 null" % node.name)
		return null

	for child in node.children:
		if child.status != Task.TaskStatus.COMPLETED:
			return _find_deepest_leaf(child)

	# 到达叶子（所有 children 已完成或无 children）
	return node


## 重新计算 _current_task：从 root 向下，优先选未完成 child，递归到最深层。
func _recalc_current() -> void:
	if _root_tasks.is_empty():
		_current_task = null
		return

	# 找到第一个 ACTIVE（或第一个未完成）的根任务
	var active_root: Task = null
	for rt in _root_tasks:
		if rt.status != Task.TaskStatus.COMPLETED:
			active_root = rt
			break

	if active_root == null:
		Logging.info("TaskManager: _recalc_current — 所有根任务已完成")
		_current_task = null
		return

	_current_task = _find_deepest_leaf(active_root)
	Logging.info("TaskManager: _recalc_current → '%s'" % (_current_task.name if _current_task else "null"))


## 尝试激活 chain_next：当前根级任务完成 → 激活链上的下一个。
func _try_activate_chain_next(completed_root: Task) -> void:
	var next_task := completed_root.chain_next
	if next_task == null:
		Logging.info("TaskManager: '%s' 无 chain_next" % completed_root.name)
		return
	if next_task.status != Task.TaskStatus.INACTIVE:
		Logging.info("TaskManager: '%s' 的 chain_next '%s' 非 INACTIVE (status=%s)，跳过" % [completed_root.name, next_task.name, next_task.status_name()])
		return

	Logging.info("TaskManager: '%s' → 激活 chain_next '%s'" % [completed_root.name, next_task.name])
	next_task.status = Task.TaskStatus.ACTIVE
	_activate_children(next_task)


# ═══════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════

## 递归激活某节点的所有子任务
func _activate_children(parent: Task) -> void:
	for child in parent.children:
		if child.status == Task.TaskStatus.INACTIVE:
			child.status = Task.TaskStatus.ACTIVE
			Logging.info("TaskManager: _activate_children — '%s' → ACTIVE" % child.name)
			_activate_children(child)
		else:
			Logging.info("TaskManager: _activate_children — '%s' 状态=%s，跳过" % [child.name, child.status_name()])


## 确定 APPEND_TO_CHILDREN 的容器节点。
## 如果 _current_task 有 children → 它就是容器（作为父任务）。
## 否则容器是 _current_task.parent（当前任务是子任务，追加到它的同层）。
## 如果 _current_task.parent 为 null → 返回 null（回退到 _root_tasks）。
func _resolve_append_container(current: Task) -> Task:
	if current.children.size() > 0:
		Logging.info("TaskManager: _resolve_append_container — '%s' 有 %d 个 children，作为父容器" % [current.name, current.children.size()])
		return current
	if current.parent != null:
		Logging.info("TaskManager: _resolve_append_container — '%s' 是子任务，容器=parent '%s'" % [current.name, current.parent.name])
		return current.parent
	Logging.info("TaskManager: _resolve_append_container — '%s' 无 children 且无 parent，回退" % current.name)
	return null


## 在树中查找某节点的 parent（遍历整棵树）。
func _find_parent_in_tree(target: Task) -> Task:
	for rt in _root_tasks:
		var result := _find_parent_recursive(rt, target)
		if result != null:
			return result
	return null


func _find_parent_recursive(node: Task, target: Task) -> Task:
	for child in node.children:
		if child == target:
			return node
		var deeper := _find_parent_recursive(child, target)
		if deeper != null:
			return deeper
	return null


## 递归清除任务及其子树的运行时状态。
func _clear_all(tasks: Array[Task]) -> void:
	for t in tasks:
		if not t:
			continue
		Logging.info("TaskManager: _clear_all — 清除 '%s'" % t.name)
		_clear_all(t.children)
		t.children.clear()
		t.status = Task.TaskStatus.INACTIVE
		t.parent = null
		t.chain_next = null


## 注册 task 及其整棵子树到 _task_registry。
func _register_task(task: Task) -> void:
	if task.uuid.is_empty():
		return
	_task_registry[task.uuid] = task
	Logging.info("TaskManager: _register_task — '%s' (%s)" % [task.name, task.uuid])
	for child in task.children:
		_register_task(child)


## 执行某个任务的所有 operators（顺序执行）。
func _execute_operators(task: Task) -> void:
	if task.operators.is_empty():
		Logging.info("TaskManager: _execute_operators — '%s' 无 operators" % task.name)
		return
	for i in range(task.operators.size()):
		var op = task.operators[i]
		if not op:
			Logging.err("TaskManager: _execute_operators — '%s' operators[%d] 为 null，跳过" % [task.name, i])
			continue
		Logging.info("TaskManager: _execute_operators — '%s' operator[%d] = %s" % [task.name, i, op.get_class()])
		op.operate()


# ═══════════════════════════════════════════════════════════
# 持久化 — GameSaveData 集成
# ═══════════════════════════════════════════════════════════

## 将当前任务树状态序列化为 Dictionary（只存 UUID 映射 + status，不存 Resource 本身）。
## 格式：
##   { "root_task_uuids": [...], "tasks": {}, "last_completed_uuid": "" }
func save_task_state() -> Dictionary:
	if _root_tasks.is_empty():
		Logging.info("TaskManager.save_task_state: 任务树为空，返回空字典")
		return {}

	var tasks_dict := {}

	for rt in _root_tasks:
		_collect_task_state(rt, tasks_dict)

	var root_uuids: Array[String] = []
	for rt in _root_tasks:
		if not rt.uuid.is_empty():
			root_uuids.append(rt.uuid)

	var last_completed_uuid := ""
	if _last_completed_task and not _last_completed_task.uuid.is_empty():
		last_completed_uuid = _last_completed_task.uuid

	var result := {
		"root_task_uuids": root_uuids,
		"tasks": tasks_dict,
		"last_completed_uuid": last_completed_uuid,
	}

	Logging.info("TaskManager.save_task_state: 序列化完成 — root_uuids=%s, tasks=%d" % [str(root_uuids), tasks_dict.size()])
	return result


## 递归收集 task 及其 children/chain_next 到 tasks_dict 中。
func _collect_task_state(t: Task, tasks_dict: Dictionary) -> void:
	if not t or t.uuid.is_empty():
		return
	if tasks_dict.has(t.uuid):
		return  # 已处理过（避免 chain_next 循环）
	tasks_dict[t.uuid] = {
		"status": t.status,
		"chain_next": t.chain_next.uuid if (t.chain_next and not t.chain_next.uuid.is_empty()) else "",
		"parent": t.parent.uuid if (t.parent and not t.parent.uuid.is_empty()) else "",
		"children": _extract_child_uuids(t),
	}
	Logging.info("TaskManager._collect_task_state: '%s' status=%d" % [t.name, t.status])
	for c in t.children:
		_collect_task_state(c, tasks_dict)
	if t.chain_next:
		_collect_task_state(t.chain_next, tasks_dict)


## 从 Dictionary 恢复任务树状态。
## 注意：Task 实例本身必须已由外部重新注入（如从 .tres 重新加载），
## 此方法仅恢复运行时状态（status, parent/children/chain_next 关联）。
## loaded_tasks: uuid → Task 的映射（由调用方在 load 时通过 Database 或直接加载 .tres 构建）。
func load_task_state(state: Dictionary, loaded_tasks: Dictionary) -> void:
	if state.is_empty():
		Logging.info("TaskManager.load_task_state: 空状态，跳过")
		return

	# 清除当前运行时
	_root_tasks.clear()
	_current_task = null
	_last_completed_task = null
	_task_registry.clear()

	var root_uuids: Array = state.get("root_task_uuids", [])
	var tasks_data: Dictionary = state.get("tasks", {})
	var last_completed_uuid: String = state.get("last_completed_uuid", "")

	if root_uuids.is_empty() or loaded_tasks.is_empty():
		Logging.info("TaskManager.load_task_state: root_uuids 或 loaded_tasks 为空，跳过")
		return

	# 第一遍：恢复每个 task 的 status
	for uuid in tasks_data:
		var t = loaded_tasks.get(uuid)
		if not t:
			Logging.err("TaskManager.load_task_state: uuid '%s' 在 loaded_tasks 中未找到" % uuid)
			continue
		var td: Dictionary = tasks_data[uuid]
		t.status = td.get("status", 0)
		_task_registry[uuid] = t

	# 第二遍：恢复关联（parent / children / chain_next）
	for uuid in tasks_data:
		var t = loaded_tasks.get(uuid)
		if not t:
			continue
		var td: Dictionary = tasks_data[uuid]

		# parent 关联
		var parent_uuid: String = td.get("parent", "")
		if not parent_uuid.is_empty():
			t.parent = loaded_tasks.get(parent_uuid)

		# children 关联
		var child_uuids: Array = td.get("children", [])
		t.children.clear()
		for cu in child_uuids:
			var child_task = loaded_tasks.get(cu)
			if child_task:
				t.children.append(child_task)

		# chain_next 关联
		var chain_uuid: String = td.get("chain_next", "")
		if not chain_uuid.is_empty():
			t.chain_next = loaded_tasks.get(chain_uuid)

	# 重建 _root_tasks
	for ru in root_uuids:
		var rt = loaded_tasks.get(ru)
		if rt:
			_root_tasks.append(rt)

	# 恢复 _last_completed_task
	if not last_completed_uuid.is_empty():
		_last_completed_task = loaded_tasks.get(last_completed_uuid)

	# 重新计算 _current_task
	_recalc_current()

	Logging.info("TaskManager.load_task_state: 恢复完成 — root_tasks=%d, current=%s" % [
		_root_tasks.size(),
		_current_task.name if _current_task else "null"
	])


## 提取某 task 的直接子任务 UUID 列表（不递归）。
func _extract_child_uuids(task: Task) -> Array[String]:
	var uuids: Array[String] = []
	for child in task.children:
		if not child.uuid.is_empty():
			uuids.append(child.uuid)
	return uuids
