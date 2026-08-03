extends VBoxContainer
## TaskContainer — 任务面板 UI 控件，挂载在 ui/task_container.tscn。
##
## 4 个 LinkButton（全部支持 hover 显示 description + requirements + operators）：
##   ParentTask  — 父任务名（仅 parent ≠ null 时可见）
##   TaskPrev     — 最近完成的任务（划掉效果）
##   CurrentTask  — 当前最深层未完成任务
##   TaskFuture   — 下一个任务（下一个兄弟 或 chain_next，仅存在时可见）
##
## 闪烁动画：完成时文字消失 + 背景变白同时发生（0.15s），然后恢复（0.15s）。

# ── 闪烁动画参数 ──
const FLASH_FADE_DURATION: float = 0.15
const FLASH_COLOR: Color = Color.WHITE

## 原始 modulate（闪烁前保存，用于恢复）
var _original_modulate: Color = Color.WHITE

## 当前是否正在执行闪烁动画
var _is_flashing: bool = false


# ═══════════════════════════════════════════════════════════
# 子节点懒获取（避免 @onready 引用被释放的竞态）
# ═══════════════════════════════════════════════════════════

func _get_parent_task_btn() -> LinkButton:
	return get_node_or_null("ParentTask") as LinkButton

func _get_task_prev_container() -> PanelContainer:
	return get_node_or_null("TaskPrev") as PanelContainer

func _get_task_prev_btn() -> LinkButton:
	return get_node_or_null("TaskPrev/TaskPrev") as LinkButton

func _get_current_task_btn() -> LinkButton:
	return get_node_or_null("CurrentTask") as LinkButton

func _get_task_future_btn() -> LinkButton:
	return get_node_or_null("TaskFuture") as LinkButton


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_original_modulate = modulate

	# 监听任务树状态变更
	if not EventBus.task_state_changed.is_connected(_on_task_state_changed):
		EventBus.task_state_changed.connect(_on_task_state_changed)
		Logging.info("TaskContainer: 已连接 EventBus.task_state_changed")

	# 初始刷新 — 直接同步调用，不用 call_deferred
	_refresh_display()


func _exit_tree() -> void:
	# 断开信号，阻止已释放节点收到回调
	if EventBus.task_state_changed.is_connected(_on_task_state_changed):
		EventBus.task_state_changed.disconnect(_on_task_state_changed)
		Logging.info("TaskContainer: 已断开 EventBus.task_state_changed")


# ═══════════════════════════════════════════════════════════
# 信号回调
# ═══════════════════════════════════════════════════════════

func _on_task_state_changed() -> void:
	# 守卫：节点已离开场景树或失效
	if not is_instance_valid(self) or not is_inside_tree():
		return

	Logging.info("TaskContainer: 收到 task_state_changed，_is_flashing=%s" % str(_is_flashing))

	if _is_flashing:
		Logging.info("TaskContainer: 正在闪烁中，排队延迟刷新")
		return

	if TaskManager.is_state_dirty():
		Logging.info("TaskContainer: 状态 dirty，执行闪烁 + 刷新")
		_flash_and_refresh()
	else:
		Logging.info("TaskContainer: 状态 clean，仅刷新文本")
		_refresh_display()


# ═══════════════════════════════════════════════════════════
# 核心刷新逻辑
# ═══════════════════════════════════════════════════════════

func _refresh_display() -> void:
	# 守卫：自身已失效或不在场景树中
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var current := TaskManager.get_current_task()
	var task_parent := TaskManager.get_parent_task()
	var next_task := TaskManager.get_next_task()
	var last_completed := TaskManager.get_last_completed_task()

	Logging.info("TaskContainer._refresh_display: current=%s, parent=%s, next=%s, prev=%s" % [
		current.name if current else "null",
		task_parent.name if task_parent else "null",
		next_task.name if next_task else "null",
		last_completed.name if last_completed else "null",
	])

	# ── ParentTask ──
	_refresh_parent_task(task_parent)

	# ── CurrentTask ──
	_refresh_current_task(current)

	# ── TaskPrev ──
	_refresh_task_prev(last_completed)

	# ── TaskFuture ──
	_refresh_task_future(next_task)

	# 消费 dirty 标志
	TaskManager.mark_state_clean()


func _refresh_parent_task(task_parent) -> void:
	var btn := _get_parent_task_btn()
	if not btn or not is_instance_valid(btn):
		Logging.err("TaskContainer: _parent_task_btn 已失效")
		return
	if task_parent != null:
		btn.text = tr(task_parent.name)
		btn.visible = true
		_register_task_hover(btn, task_parent, "ParentTask")
		Logging.info("TaskContainer: ParentTask → '%s'" % task_parent.name)
	else:
		btn.visible = false
		_register_task_hover(btn, null, "ParentTask")
		Logging.info("TaskContainer: ParentTask → 隐藏")


func _refresh_current_task(current) -> void:
	var btn := _get_current_task_btn()
	if not btn or not is_instance_valid(btn):
		Logging.err("TaskContainer: _current_task_btn 已失效")
		return
	if current != null:
		btn.text = tr(current.name)
		btn.visible = true
		_register_task_hover(btn, current, "CurrentTask")
		Logging.info("TaskContainer: CurrentTask → '%s'" % current.name)
	else:
		btn.visible = false
		_register_task_hover(btn, null, "CurrentTask")
		Logging.info("TaskContainer: CurrentTask → 隐藏（无任务）")


func _refresh_task_prev(last_completed) -> void:
	var container := _get_task_prev_container()
	var btn := _get_task_prev_btn()
	if not container or not is_instance_valid(container):
		Logging.err("TaskContainer: _task_prev_container 已失效")
		return
	if not btn or not is_instance_valid(btn):
		Logging.err("TaskContainer: _task_prev_btn 已失效")
		return
	if last_completed != null:
		btn.text = "[s]%s[/s]" % tr(last_completed.name)
		container.visible = true
		_register_task_hover(btn, last_completed, "TaskPrev")
		Logging.info("TaskContainer: TaskPrev → '%s' (划掉)" % last_completed.name)
	else:
		container.visible = false
		_register_task_hover(btn, null, "TaskPrev")
		Logging.info("TaskContainer: TaskPrev → 隐藏")


func _refresh_task_future(next_task) -> void:
	var btn := _get_task_future_btn()
	if not btn or not is_instance_valid(btn):
		Logging.err("TaskContainer: _task_future_btn 已失效")
		return
	if next_task != null:
		btn.text = "→ %s" % tr(next_task.name)
		btn.visible = true
		_register_task_hover(btn, next_task, "TaskFuture")
		Logging.info("TaskContainer: TaskFuture → '%s'" % next_task.name)
	else:
		btn.visible = false
		_register_task_hover(btn, null, "TaskFuture")
		Logging.info("TaskContainer: TaskFuture → 隐藏")


# ═══════════════════════════════════════════════════════════
# 闪烁动画
# ═══════════════════════════════════════════════════════════

## 先隐后现的闪烁动画：文字消失 + 背景变白（同时发生），0.15s 后恢复。
func _flash_and_refresh() -> void:
	if not is_instance_valid(self):
		return

	_is_flashing = true
	_original_modulate = modulate

	# Phase 1: 文字透明 + 背景变白（同时，0.15s）
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:r", FLASH_COLOR.r, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:g", FLASH_COLOR.g, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:b", FLASH_COLOR.b, FLASH_FADE_DURATION)

	# Phase 2: 更新文字 + 恢复（在 Phase 1 之后顺序执行）
	tween.chain().tween_callback(_refresh_display)
	tween.tween_callback(func():
		if not is_instance_valid(self) or not is_inside_tree():
			_is_flashing = false
			return
		var t2 := create_tween()
		t2.set_parallel(true)
		t2.tween_property(self, "modulate:a", _original_modulate.a, FLASH_FADE_DURATION)
		t2.tween_property(self, "modulate:r", _original_modulate.r, FLASH_FADE_DURATION)
		t2.tween_property(self, "modulate:g", _original_modulate.g, FLASH_FADE_DURATION)
		t2.tween_property(self, "modulate:b", _original_modulate.b, FLASH_FADE_DURATION)
		t2.tween_callback(func():
			_is_flashing = false
			Logging.info("TaskContainer: 闪烁动画完成")
		)
	)

	Logging.info("TaskContainer: 闪烁动画已启动（%.2fs 消失 + %.2fs 恢复）" % [FLASH_FADE_DURATION, FLASH_FADE_DURATION])


# ═══════════════════════════════════════════════════════════
# Hover 注册 — 为四个任务按钮注入详情提示
# ═══════════════════════════════════════════════════════════

## 通用 hover 注册：先 unregister 清理旧绑定，再 register 新绑定。
## task 为 null 时仅清理，不注册新 hover。
func _register_task_hover(btn: Control, task: Task, label: String) -> void:
	if not btn or not is_instance_valid(btn):
		return

	# 先清理旧绑定，避免重复注册累积
	HoverPopupManager.unregister(btn)

	if not task:
		Logging.info("TaskContainer: %s hover 已清除" % label)
		return

	var narrative_text := _build_task_hover_text(task)

	HoverPopupManager.register(
		btn,
		{"narrative": narrative_text, "vector": ""},
		0.2,
		1.0,
		HoverPopupManager.FlowType.BELOW_OVERLAY,
	)

	Logging.info("TaskContainer: %s hover 已注册 — '%s'" % [label, task.name])


## 构建任务的 hover 提示文本（BBCode）。
func _build_task_hover_text(task: Task) -> String:
	var parts: Array[String] = []

	# description
	if not task.description.is_empty():
		parts.append(task.description)
		parts.append("")  # 空行分隔

	# requirements
	if not task.requirements.is_empty():
		parts.append("[b]需求:[/b]")
		for req in task.requirements:
			if not req:
				continue
			var hint_text := req.describe_requirement()
			if hint_text.is_empty():
				hint_text = req.get_failed_hint()
			if hint_text.is_empty():
				hint_text = req.get_class()  # 兜底：显示类名
			parts.append("  • %s" % hint_text)
		parts.append("")

	# operators
	if not task.operators.is_empty():
		parts.append("[b]完成奖励:[/b]")
		for op in task.operators:
			if not op:
				continue
			var preview := op.describe_preview()
			if preview.is_empty():
				preview = op.get_class()  # 兜底
			parts.append("  • %s" % preview)

	return "\n".join(parts)
