class_name NarrativeDirector extends Node

# ═══════════════════════════════════════════════
# 出站信号（发往 NarrativeOverlay / TapeVisualizer）
# ═══════════════════════════════════════════════

signal tape_needs_show()
signal tape_needs_hide()
signal event_ready_to_play(entry: Dictionary, from_stack: bool)
signal picker_ready(entry: Dictionary)
signal cinematic_ready(entry: Dictionary)
signal focused_chat_ready(entry: Dictionary)
signal interrupt_available(event_key: String, context: Dictionary, btn_text: String, btn_color: Color)
signal interrupt_unavailable()
signal animation_tracking_started()
signal event_confirmed_out()
signal pop_return_text_ready(text: String)


# ═══════════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════════

var _event_queue: Array[Dictionary] = []
var _event_stack: Array[Dictionary] = []
var _is_active: bool = false
var _is_checking_interruption: bool = false
var _current_from_stack: bool = false
var _saved_time_scale: float = 1.0
var _pending_interrupt_event_key: String = ""
var _pending_interrupt_context: Dictionary = {}
var _active_animations: Array = []
var _waiting_for_animations: bool = false
var _current_event_data: BaseEvent = null


# ═══════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	EventBus.push_event.connect(_on_push_event)
	EventBus.pop_event.connect(_on_pop_event)
	EventBus.pop_to_event.connect(_on_pop_to_event)
	EventBus.clear_scheduled_events.connect(_on_clear_scheduled_events)
	EventBus.push_picker.connect(_on_push_picker)
	EventBus.push_cinematic.connect(_on_push_cinematic)
	EventBus.push_focused_chat.connect(_on_push_focused_chat)
	EventBus.request_event.connect(_on_request_event)
	EventBus.request_event_key.connect(_on_request_event_key)
	EventBus.request_track_stage_animation.connect(_on_track_animation)


# ═══════════════════════════════════════════════
# EventBus 信号回调 — Stack / Queue 管理
# ═══════════════════════════════════════════════

func _on_push_event(data: Variant, context: Dictionary):
	var ev = _resolve_event_for_stack(data)
	if not ev:
		return

	if ev is RandomEvent and ev.requirement:
		ev.requirement.init(context)
		if not ev.requirement.compare(PlayerState):
			Logging.warn("push_event: 事件 '%s' 的 entry requirement 未通过，忽略 push" % ev.name)
			return

	_event_stack.push_front({ "data": ev, "context": context.duplicate(true), "processed": false })
	Logging.info("事件已推入栈: " + ev.name)

	if not _is_active:
		_process_next()


func _on_pop_event(transition_text: String = ""):
	if _event_stack.size() > 0:
		var entry = _event_stack.pop_front()
		if entry.has("data"):
			var ev: BaseEvent = entry.get("data")
			if not entry.get("processed", false):
				Logging.err("pop_event: 事件 '%s' 被弹出但从未被处理过！可能存在事件丢失" % ev.name)
			Logging.info("pop_event: 弹出栈事件 - " + ev.name)
		else:
			Logging.info("pop_event: 弹出栈条目")
	else:
		Logging.warn("pop_event: 栈为空，无事件可弹出")

	if _event_stack.size() > 0:
		var top_entry = _event_stack[0]
		if top_entry.has("data") and top_entry.get("data") is BaseEvent:
			var parent_ev: BaseEvent = top_entry.get("data")
			var on_returned: String = parent_ev.on_returned

			var combined_text := ""
			if not transition_text.is_empty() and not on_returned.is_empty():
				combined_text = transition_text + "\n\n" + on_returned
			elif not transition_text.is_empty():
				combined_text = transition_text
			elif not on_returned.is_empty():
				combined_text = on_returned

			if not combined_text.is_empty():
				Logging.info("pop_event: 发射 pop_return_text_ready (transition='%s' on_returned='%s')" % [transition_text, on_returned])
				pop_return_text_ready.emit(combined_text)
			else:
				Logging.debug("pop_event: transition_text 和 on_returned 均为空，跳过")

		# pop_event 不在此调用 _process_next() — 由 on_option_selected() guard 分支负责
		# 将栈顶父事件的 processed 重置为 false，等待 guard 唤醒 _process_next()
		if _event_stack.size() > 0:
			_event_stack[0]["processed"] = false


func _on_clear_scheduled_events():
	var stack_size = _event_stack.size()
	var queue_size = _event_queue.size()
	_event_stack.clear()
	_event_queue.clear()

	Logging.info("ClearScheduledEvents: 已清空栈（%d 条目）和队列（%d 条目）" % [stack_size, queue_size])


func _on_pop_to_event(event_key: String):
	for i in range(_event_stack.size()):
		var entry = _event_stack[i]
		if not entry.has("data"):
			continue
		if entry.get("type") == "picker" or entry.get("type") == "cinematic" or entry.get("type") == "focused_chat":
			continue
		var ev: BaseEvent = entry.get("data")
		if _event_identity_matches(ev, event_key):
			for _j in range(i):
				_event_stack.pop_front()
			var target_entry = _event_stack.pop_front()
			if target_entry.has("data"):
				target_entry["processed"] = false
			_event_stack.push_front(target_entry)
			Logging.info("pop_to_event: 已弹出 %d 个条目，目标事件 '%s' 保留在栈顶" % [i, event_key])
			_process_next()
			return

	Logging.warn("pop_to_event: 未找到目标事件 '%s'，栈中无匹配条目" % event_key)


func _event_identity_matches(ev: BaseEvent, event_key: String) -> bool:
	if ev._namespace and event_key.begins_with(ev._namespace):
		return true
	return false


func _on_push_picker(data: Array, on_selected: Callable, ui_constructor = null):
	var entry := {
		"type": "picker",
		"data": data,
		"on_selected": on_selected,
		"ui_constructor": ui_constructor,
	}
	_event_stack.push_front(entry)
	Logging.info("Picker 已推入栈顶，%d 个选项" % data.size())

	if not _is_active:
		_process_next()


func _on_push_focused_chat(data: Variant, context: Dictionary = {}):
	var entry := {
		"type": "focused_chat",
		"data": data,
		"context": context.duplicate(),
		"processed": false,
	}
	_event_stack.push_front(entry)
	Logging.info("FocusChat 已推入栈顶")

	if not _is_active:
		_process_next()


func _on_push_cinematic(texts: Array[String]):
	var entry := {
		"type": "cinematic",
		"texts": texts.duplicate(),
		"processed": false,
	}
	_event_stack.push_front(entry)
	Logging.info("Cinematic 已推入栈顶，%d 段文字" % texts.size())

	if not _is_active:
		_process_next()


func _resolve_event_for_stack(data: Variant) -> BaseEvent:
	if data is BaseEvent:
		return data
	if data is String:
		var ev = Database.resolve(data)
		if not ev:
			breakpoint
			Logging.err("push_event: Event not found: " + data)
			Logging.err("检查你是不是又加了某个事件文件夹没写判断")
			return null
		return ev
	Logging.err("push_event: 不支持的数据类型: " + str(typeof(data)))
	return null


func _on_request_event(data, context):
	_event_queue.append({ "data": data, "context": context })
	Logging.info("request_event: 事件已入队")
	if not _is_active:
		_process_next()


func _on_request_event_key(key: String, context):
	var ev = Database.resolve(key)
	if not ev:
		breakpoint
		Logging.err("Event not found: " + key)
		Logging.err("检查你是不是又加了某个事件文件夹没写判断")
		return
	_event_queue.append({ "data": ev, "context": context })
	Logging.info("request_event_key: 事件 '%s' 已入队" % key)
	if not _is_active:
		_process_next()


# ═══════════════════════════════════════════════
# 核心状态机
# ═══════════════════════════════════════════════

func _process_next():
	if _is_active:
		return

	if not _active_animations.is_empty():
		_waiting_for_animations = true
		Logging.info("_process_next: 等待 %d 个动画完成，挂起" % _active_animations.size())
		return

	# ── 栈优先 (LIFO) ──
	if _event_stack.size() > 0:
		var entry = _event_stack[0]

		if entry is Dictionary and entry.get("type") == "picker":
			Logging.info("_process_next: 处理栈顶 Picker")
			_is_active = true
			_pause_world()
			picker_ready.emit(entry)
			return

		if entry is Dictionary and entry.get("type") == "cinematic":
			Logging.info("_process_next: 处理栈顶 Cinematic")
			entry["processed"] = true
			_is_active = true
			_pause_world()
			cinematic_ready.emit(entry)
			return

		if entry is Dictionary and entry.get("type") == "focused_chat":
			Logging.info("_process_next: 处理栈顶 FocusChat")
			entry["processed"] = true
			_is_active = true
			_pause_world()
			focused_chat_ready.emit(entry)
			return

		# BaseEvent 条目
		_current_from_stack = true
		entry["processed"] = true
		var ev: BaseEvent = entry.get("data")
		var ctx: Dictionary = entry.get("context", {})
		Logging.info("_process_next: 处理栈顶事件 '%s'" % ev.name)

		# 中断检查
		if not _is_checking_interruption and ev.has_method("check_interruption"):
			_is_checking_interruption = true
			ev.check_interruption(ctx)
			_is_checking_interruption = false
			if _is_active:
				Logging.info("_process_next: 事件 '%s' 被中断序列替换" % ev.name)
				return

		_current_event_data = ev
		_is_active = true
		_pause_world()

		_emit_interrupt_signals(ctx)

		event_ready_to_play.emit(entry, true)
		return

	# ── 队列其次 (FIFO) ──
	if _event_queue.size() > 0:
		var queued = _event_queue.pop_front()
		_current_from_stack = false
		var next_event: BaseEvent = queued.get("data")
		var next_context: Dictionary = queued.get("context", {})
		Logging.info("_process_next: 处理队列事件 '%s'" % next_event.name)

		if not _is_checking_interruption and next_event.has_method("check_interruption"):
			_is_checking_interruption = true
			next_event.check_interruption(next_context)
			_is_checking_interruption = false
			if _is_active:
				Logging.info("_process_next: 队列事件 '%s' 被中断序列替换" % next_event.name)
				return

		_current_event_data = next_event
		_is_active = true
		_pause_world()

		_emit_interrupt_signals(next_context)

		event_ready_to_play.emit({ "data": next_event, "context": next_context }, false)
		return

	# ── 栈和队列全空 ──
	Logging.info("_process_next: 栈和队列全空，发射 tape_needs_hide")
	tape_needs_hide.emit()


func _emit_interrupt_signals(ctx: Dictionary):
	var interrupt_data = ctx.get("interrupt_event", null)
	if interrupt_data is Dictionary:
		var event_key = interrupt_data.get("event_key", "")
		if not event_key.is_empty():
			_pending_interrupt_event_key = event_key
			_pending_interrupt_context = ctx.duplicate(true)
			_pending_interrupt_context.erase("interrupt_event")
			var btn_text: String = interrupt_data.get("text", "中断")
			var btn_color: Color = interrupt_data.get("color", Color(0.70, 0.15, 0.30))
			Logging.info("_emit_interrupt_signals: 中断可用 event_key='%s' btn_text='%s'" % [event_key, btn_text])
			interrupt_available.emit(event_key, _pending_interrupt_context, btn_text, btn_color)
		else:
			Logging.debug("_emit_interrupt_signals: interrupt_event 存在但 event_key 为空")
			interrupt_unavailable.emit()
	else:
		_pending_interrupt_event_key = ""
		_pending_interrupt_context = {}
		Logging.debug("_emit_interrupt_signals: context 中无 interrupt_event")
		interrupt_unavailable.emit()


# ═══════════════════════════════════════════════
# 世界暂停 / 恢复
# ═══════════════════════════════════════════════

func _pause_world():
	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)
	Logging.info("NarrativeDirector: 世界已暂停 (saved_time_scale=%.2f)" % _saved_time_scale)


func _resume_world():
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	Logging.info("NarrativeDirector: 世界已恢复 (time_scale=%.2f)" % _saved_time_scale)


# ═══════════════════════════════════════════════
# 入站公共方法（被 NarrativeOverlay 调用）
# ═══════════════════════════════════════════════

func on_option_selected(choice, choice_text: String = ""):
	Logging.info("NarrativeDirector.on_option_selected: choice_text='%s'" % choice_text)

	EventBus.event_confirmed.emit()
	event_confirmed_out.emit()

	var _completed_data: BaseEvent = _current_event_data

	await ConsequenceExecuter.execute_result(choice)

	# 守卫：处理 execute_result 期间可能激活的栈条目
	if _event_stack.size() > 0 and _event_stack[0].get("processed", false):
		var guard_entry = _event_stack[0]
		var entry_type = guard_entry.get("type", "")

		if guard_entry.get("data") == _completed_data:
			_event_stack.pop_front()
			Logging.info("on_option_selected: 自动弹出已完成的栈事件 '%s'" % _completed_data.name)
		elif entry_type in ["focused_chat", "picker", "cinematic"]:
			Logging.info("on_option_selected: 栈顶条目已处理（type='%s'），跳过 _is_active 重置" % entry_type)
			_resume_world()
			return
		else:
			# 栈顶是 pop 回归后的父事件 (BaseEvent, processed=true)
			# 不弹出！重置 processed=false，让 _process_next 重新处理
			Logging.info("on_option_selected: 检测到 pop 回归父事件，重置 processed 标记")
			_event_stack[0]["processed"] = false

	_is_active = false
	_resume_world()
	_process_next()


func on_interrupt_pressed():
	if not _is_active:
		Logging.warn("NarrativeDirector.on_interrupt_pressed: 非活跃状态，忽略重复点击")
		return

	Logging.info("NarrativeDirector.on_interrupt_pressed: 中断按钮被点击，目标事件='%s'" % _pending_interrupt_event_key)

	_resume_world()
	EventBus.event_confirmed.emit()
	event_confirmed_out.emit()

	if _event_stack.size() > 0:
		var top_entry = _event_stack[0]
		if top_entry.has("data") and top_entry.get("data") == _current_event_data:
			_event_stack.pop_front()
			Logging.info("on_interrupt_pressed: 已弹出栈顶事件 '%s'" % _current_event_data.name)
		else:
			Logging.info("on_interrupt_pressed: 当前事件不在栈顶，不操作栈")
	else:
		Logging.info("on_interrupt_pressed: 栈为空，不操作栈")

	var target_event_key := _pending_interrupt_event_key
	var target_context := _pending_interrupt_context
	_pending_interrupt_event_key = ""
	_pending_interrupt_context = {}

	_is_active = false

	if not target_event_key.is_empty():
		EventBus.push_event.emit(target_event_key, target_context)
		Logging.info("on_interrupt_pressed: 目标事件 '%s' 已入栈" % target_event_key)

	Logging.info("on_interrupt_pressed: 中断流程完成，处理下一个事件")
	_process_next()


func on_picker_item_selected(entity):
	if _event_stack.size() == 0:
		Logging.warn("on_picker_item_selected: 栈为空，没有 picker 条目")
		return

	var entry = _event_stack.pop_front()
	Logging.info("Picker 已从栈中弹出，选择了: %s" % str(entity))

	var callback: Callable = entry.get("on_selected", Callable())
	if callback.is_valid():
		callback.call(entity)

	_resume_world()
	_is_active = false
	_process_next()


func on_focused_chat_finished(result):
	_event_stack.pop_front()
	Logging.info("FocusChat 已从栈中弹出")

	if result:
		ConsequenceExecuter.execute_result(result)

	_resume_world()
	_is_active = false
	_process_next()


func on_cinematic_finished():
	_event_stack.pop_front()
	Logging.info("Cinematic 已从栈中弹出")

	_resume_world()
	_is_active = false
	_process_next()


# ═══════════════════════════════════════════════
# 动画追踪
# ═══════════════════════════════════════════════

func _on_track_animation(anim):
	if anim.finished.is_connected(_on_animation_finished.bind(anim)):
		return
	_active_animations.append(anim)
	anim.finished.connect(_on_animation_finished.bind(anim), CONNECT_ONE_SHOT)
	anim.start()
	Logging.info("NarrativeDirector: 追踪动画 %s，当前活跃动画数=%d" % [anim, _active_animations.size()])


func _on_animation_finished(anim):
	_active_animations.erase(anim)
	Logging.info("NarrativeDirector: 动画完成 %s，剩余活跃动画数=%d" % [anim, _active_animations.size()])
	if _waiting_for_animations and _active_animations.is_empty():
		_waiting_for_animations = false
		Logging.info("NarrativeDirector: 所有动画完成，恢复事件处理")
		_process_next()
