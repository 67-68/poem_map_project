extends VBoxContainer
## TaskContainer — 任务面板 UI 控件，挂载在 ui/task_container.tscn。
##
## 4 个 LinkButton：
##   ParentTask  — 父任务名（仅 parent ≠ null 时可见）
##   TaskPrev     — 最近完成的任务（划掉效果，hover 弹出详情）
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


@onready var _parent_task_btn: LinkButton = $ParentTask
@onready var _task_prev_container: PanelContainer = $TaskPrev
@onready var _task_prev_btn: LinkButton = $TaskPrev/TaskPrev
@onready var _current_task_btn: LinkButton = $CurrentTask
@onready var _task_future_btn: LinkButton = $TaskFuture


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_original_modulate = modulate

	# 监听任务树状态变更
	if not EventBus.task_state_changed.is_connected(_on_task_state_changed):
		EventBus.task_state_changed.connect(_on_task_state_changed)
		Logging.info("TaskContainer: 已连接 EventBus.task_state_changed")

	# 初始刷新
	call_deferred("_refresh_display")


# ═══════════════════════════════════════════════════════════
# 信号回调
# ═══════════════════════════════════════════════════════════

func _on_task_state_changed() -> void:
	Logging.info("TaskContainer: 收到 task_state_changed，_is_flashing=%s" % str(_is_flashing))

	if _is_flashing:
		Logging.info("TaskContainer: 正在闪烁中，排队延迟刷新")
		# 等当前闪烁完成后再刷新（闪烁完成后调用 _refresh_display）
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
	var current := TaskManager.get_current_task()
	var parent := TaskManager.get_parent_task()
	var next_task := TaskManager.get_next_task()
	var last_completed := TaskManager.get_last_completed_task()

	Logging.info("TaskContainer._refresh_display: current=%s, parent=%s, next=%s, prev=%s" % [
		current.name if current else "null",
		parent.name if parent else "null",
		next_task.name if next_task else "null",
		last_completed.name if last_completed else "null",
	])

	# ── ParentTask ──
	if parent != null:
		_parent_task_btn.text = parent.name
		_parent_task_btn.visible = true
		Logging.info("TaskContainer: ParentTask → '%s'" % parent.name)
	else:
		_parent_task_btn.visible = false
		Logging.info("TaskContainer: ParentTask → 隐藏")

	# ── CurrentTask ──
	if current != null:
		_current_task_btn.text = current.name
		_current_task_btn.visible = true
		Logging.info("TaskContainer: CurrentTask → '%s'" % current.name)
	else:
		_current_task_btn.visible = false
		Logging.info("TaskContainer: CurrentTask → 隐藏（无任务）")

	# ── TaskPrev ──
	if last_completed != null:
		_task_prev_btn.text = "[s]%s[/s]" % last_completed.name
		_task_prev_container.visible = true
		_register_task_prev_hover(last_completed)
		Logging.info("TaskContainer: TaskPrev → '%s' (划掉)" % last_completed.name)
	else:
		_task_prev_container.visible = false
		Logging.info("TaskContainer: TaskPrev → 隐藏")

	# ── TaskFuture ──
	if next_task != null:
		_task_future_btn.text = "→ %s" % next_task.name
		_task_future_btn.visible = true
		Logging.info("TaskContainer: TaskFuture → '%s'" % next_task.name)
	else:
		_task_future_btn.visible = false
		Logging.info("TaskContainer: TaskFuture → 隐藏")

	# 消费 dirty 标志
	TaskManager.mark_state_clean()


# ═══════════════════════════════════════════════════════════
# 闪烁动画
# ═══════════════════════════════════════════════════════════

## 先隐后现的闪烁动画：文字消失 + 背景变白（同时发生），0.15s 后恢复。
func _flash_and_refresh() -> void:
	_is_flashing = true

	# 保存当前 modulate
	_original_modulate = modulate

	# Phase 1: 文字透明 + 背景变白（同时）
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:r", FLASH_COLOR.r, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:g", FLASH_COLOR.g, FLASH_FADE_DURATION)
	tween.tween_property(self, "modulate:b", FLASH_COLOR.b, FLASH_FADE_DURATION)

	tween.chain().set_parallel(true)
	# 在 Phase 1 结束后更新文字内容
	tween.chain().tween_callback(_refresh_display)
	# Phase 2: 恢复文字 + 恢复原色（同时）
	tween.chain().tween_callback(func():
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
# TaskPrev Hover — 展示已完成任务的详情
# ═══════════════════════════════════════════════════════════

func _register_task_prev_hover(task: Task) -> void:
	if not task:
		return

	# 构建 hover 文本：description + requirements + operators
	var narrative_text := _build_task_hover_text(task)
	
	HoverPopupManager.register(
		_task_prev_btn,
		{"narrative": narrative_text, "vector": ""},
		0.2,
		1.0,
		HoverPopupManager.FlowType.BELOW_OVERLAY,
	)

	Logging.info("TaskContainer: TaskPrev hover 已注册 — '%s'" % task.name)


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
