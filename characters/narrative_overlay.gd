class_name NarrativeOverlay extends PanelContainer

# 纸带模式（极乐迪斯科式）：NarrativeOverlay 不再是一次性弹窗，
# 而是持续的追加式事件纸带。纸带全空时才 hide()。
#
# 四种条目类型：
#   - Event: 完整 TapeEntry（标题+正文+选项），选后选项变文本烙印
#   - Cinematic: 照常弹出 CinematicOverlay，播完后纸带追加 stub 摘要
#   - Picker: 照常弹出 Picker，选完后纸带追加 stub 摘要
#   - FocusChat: 照常弹出 FocusChatOverlay，播完后纸带追加 stub 摘要
#
# dim 策略:
#   - Queue → 新 Event 条目: dim_previous_entries()
#   - Stack → 新 Event 条目: 不 dim
#   - Stack → 回归 Event 条目: clear_all_dim()
#   - 特殊条目 stub: 不主动 dim（跟随纸带当前状态）

# 引用子节点
# 🚨 event_ui 不写类型注解：class_name EventUI 在 parse 时尚未注册，
# 但运行时 Godot 能正确解析 $EventUI 节点，调用方法无问题。
@onready var event_ui = $EventHistory
# InterruptButton: ShadowBox 层级的右侧红色中断按钮
@onready var _interrupt_button: Button = $"../InterruptButton/Button"

# 状态
var current_event_data: BaseEvent
var _tween: Tween
# Auto-advance Timer：事件无选项或只有单选项时的自动推进计时器
var _auto_advance_timer: Timer = null

# 纸带是否已首次展示（控制 dimmer 淡入只播一次）
var _tape_initialized: bool = false
# 纸带静止时的 Y 偏移（动态读取于 _show_tape 首次调用，此时布局必定完成）
var _tape_target_y: float = 0.0

# 事件队列 (FIFO)，防止多个事件相互覆盖
# 每个元素为 { "data": BaseEvent, "context": Dictionary }
var _event_queue: Array[Dictionary] = []

# 事件栈 (LIFO)，优先级高于普通队列
# 栈中的事件会先于队列处理；栈空时才处理队列
# 支持多种条目类型：
#   - BaseEvent 条目: { "data": BaseEvent, "context": Dictionary }
#   - Picker 条目:    { "type": "picker", "data": Array, "on_selected": Callable, "ui_constructor": Callable }
#   - Cinematic 条目: { "type": "cinematic", "texts": Array[String], "processed": bool }
#   - FocusChat 条目: { "type": "focused_chat", "data": Variant, "context": Dictionary, "processed": bool }
var _event_stack: Array[Dictionary] = []

var _is_active: bool = false
# 中断检查递归保护：阻止 check_interruption -> push_event -> apply_narrative 无限循环
var _is_checking_interruption: bool = false
var _current_from_stack: bool = false
var _saved_time_scale: float = 1.0

# 中断按钮状态 — 存储 context.interrupt_event 中的 event_key 和清理后的 context
var _pending_interrupt_event_key: String = ""
var _pending_interrupt_context: Dictionary = {}

## 结算面板标记 — is_settlement 事件使用 Picker 式全屏高斯模糊而非事件层地图模糊
var _is_settlement: bool = false

# 动画追踪 — 等待后台 AnimationObject 播完再处理下一个事件
var _active_animations: Array[AnimationObject] = []
var _waiting_for_animations: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# EventUI 的选项选择信号桥接回 NarrativeOverlay 的生命周期
	event_ui.option_selected.connect(_on_option_selected)
	_interrupt_button.pressed.connect(_on_interrupt_pressed)
	Logging.info("NarrativeOverlay._ready: _interrupt_button 引用=%s, visible=%s, parent=%s, parent.visible=%s, Label.text='%s', tooltip='%s'" % [
		_interrupt_button,
		_interrupt_button.visible,
		_interrupt_button.get_parent(),
		_interrupt_button.get_parent().visible,
		_interrupt_button.get_node_or_null("Label").text if _interrupt_button.get_node_or_null("Label") else "(null)",
		_interrupt_button.tooltip_text
	])
	EventBus.request_event.connect(func(data, _context): apply_narrative(data, _context))
	EventBus.request_event_key.connect(func(key, _context):
		var ev = Database.resolve(key)
		if not ev:
			breakpoint
			Logging.err("Event not found: " + key)
			Logging.err("检查你是不是又加了某个事件文件夹没写判断")
			return
		apply_narrative(ev, _context)
	)
	EventBus.push_event.connect(_on_push_event)
	EventBus.pop_event.connect(_on_pop_event)
	EventBus.pop_to_event.connect(_on_pop_to_event)
	EventBus.clear_scheduled_events.connect(_on_clear_scheduled_events)
	EventBus.push_picker.connect(_on_push_picker)
	EventBus.push_cinematic.connect(_on_push_cinematic)
	EventBus.push_focused_chat.connect(_on_push_focused_chat)
	EventBus.request_track_stage_animation.connect(track_animation)

	# 确保这玩意在暂停时也能点
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 纸带模式：不在 _ready 中 hide()，由 _process_next 在带空时 hide()


# ═══════════════════════════════════════════════
# 纸带首次展示
# ═══════════════════════════════════════════════

func _show_tape():
	"""显示纸带面板 — 从屏幕顶部外滑入 + 透明度渐变 + 纸张摩擦音效

	   ⚠️ NarrativeOverlay 现在被包在 ShadowBox(PanelContainer) 内，
	   NarrativeOverlay.position 受父容器布局控制（layout_mode=2），
	   因此动画必须操作 ShadowBox 的 position:y。
	"""
	var shadow := get_parent()

	if _tape_initialized:
		shadow.show()
		show()
		return

	_tape_initialized = true
	if _tween: _tween.kill()

	# ── 延迟记录 ShadowBox 的静止位置（第一次调用时布局必定完成）──
	if _tape_target_y == 0.0:
		_tape_target_y = shadow.position.y
		Logging.info("_show_tape: 记录 ShadowBox 静止 position.y=%s" % _tape_target_y)

	# ── 诊断日志 ──
	var viewport_height := get_viewport_rect().size.y
	Logging.info("=== _show_tape 动画日志 ===")
	Logging.info("viewport_height=%s | ShadowBox._tape_target_y=%s" % [viewport_height, _tape_target_y])

	# ── 1. 物理重置：ShadowBox 埋到屏幕顶部外 ──
	shadow.position.y = -(viewport_height + 100.0)
	Logging.info("重置后 ShadowBox.position.y=%s → Tween 目标=%s" % [shadow.position.y, _tape_target_y])
	modulate.a = 0.0

	# 显示自身和父容器
	shadow.show()
	show()

	# ── 2. 音效：纸张摩擦声 ──
	AudioManager.play_sfx(load("res://assets/sounds/rustling_paper.wav"))

	# ── 3. 并行 Tween：ShadowBox 下落刹车 + NarrativeOverlay 显形 ──
	Logging.info("==============================")

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)

	# CUBIC + EASE_OUT：「快速拔出 → 极速刹车 → 稳稳停住」
	# 🚨 关键：tween 的是 ShadowBox.position:y，不是 self.position:y！
	_tween.tween_property(shadow, "position:y", _tape_target_y, 0.65) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# SINE EASE_IN_OUT：前 0.3 秒平滑显形，避免像素撕裂
	_tween.tween_property(self, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- 事件栈处理 ----------------------------------------

func _on_push_event(data: Variant, context: Dictionary):
	var ev = _resolve_event_for_stack(data)
	if not ev:
		return

	# 🚨 检查目标事件的 entry requirement
	if ev is RandomEvent and ev.requirement:
		ev.requirement.init(context)
		if not ev.requirement.compare(PlayerState):
			Logging.warn("push_event: 事件 '%s' 的 entry requirement 未通过，忽略 push" % ev.name)
			return

	_event_stack.push_front({ "data": ev, "context": context.duplicate(true), "processed": false })
	Logging.info("事件已推入栈: " + ev.name)

	if not _is_active:
		_process_stack()


func _on_pop_event(transition_text: String = ""):
	# ── 1. 弹出栈顶（子事件）──
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

	# ── 2. 回归过渡处理：peek 栈顶父事件，合并打印 NarrativeText + invalidate 旧条目 ──
	# 只有栈顶是 BaseEvent 条目时才处理（picker/cinematic/focused_chat 不需要回归叙事）
	if _event_stack.size() > 0:
		var top_entry = _event_stack[0]
		if top_entry.has("data") and top_entry.get("data") is BaseEvent:
			var parent_ev: BaseEvent = top_entry.get("data")
			var on_returned: String = parent_ev.on_returned

			# 合并 transition_text + on_returned 为一个 NarrativeText 条目
			var combined_text := ""
			if not transition_text.is_empty() and not on_returned.is_empty():
				combined_text = transition_text + "\n\n" + on_returned
			elif not transition_text.is_empty():
				combined_text = transition_text
			elif not on_returned.is_empty():
				combined_text = on_returned

			if not combined_text.is_empty():
				Logging.info("pop_event: 打印回归过渡 NarrativeText (transition='%s' on_returned='%s')" % [transition_text, on_returned])
				event_ui.append_narrative_text(combined_text)
			else:
				Logging.debug("pop_event: transition_text 和 on_returned 均为空，跳过 NarrativeText 打印")

			# 废弃父事件的旧条目，让 apply_narrative 走新事件路径创建全新条目
			var parent_entry_id := str(parent_ev.get_instance_id())
			if event_ui.has_entry(parent_entry_id):
				event_ui.invalidate_entry(parent_entry_id)
				Logging.info("pop_event: 已废弃父事件 '%s' 的旧条目，将创建全新条目" % parent_ev.name)

	# ── 3. 处理栈/队列中的下一个事件 ──
	# 纸带模式：pop 后立即让 _process_next 处理栈/队列中的下一个，
	# 可能触发回归路径（此时 has_entry 返回 false → 新事件路径）
	_process_next()


func _on_clear_scheduled_events():
	var stack_size = _event_stack.size()
	var queue_size = _event_queue.size()
	_event_stack.clear()
	_event_queue.clear()

	Logging.info("ClearScheduledEvents: 已清空栈（%d 条目）和队列（%d 条目）" % [stack_size, queue_size])


func _on_pop_to_event(event_key: String):
	# 从栈顶向下找到目标事件，pop 掉它上方的所有条目
	for i in range(_event_stack.size()):
		var entry = _event_stack[i]
		if not entry.has("data"):
			continue
		if entry.type == "picker" or entry.type == "cinematic" or entry.type == "focused_chat":
			continue
		var ev: BaseEvent = entry.get("data")
		if _event_identity_matches(ev, event_key):
			# 弹出 i 个条目（目标以上的），保留目标本身
			for _j in range(i):
				_event_stack.pop_front()
			# 目标事件本身保留在栈顶
			var target_entry = _event_stack.pop_front()
			if target_entry.has("data"):
				target_entry["processed"] = false  # 重置，让 _process_next 重新展示
			_event_stack.push_front(target_entry)
			Logging.info("pop_to_event: 已弹出 %d 个条目，目标事件 '%s' 保留在栈顶" % [i, event_key])
			_process_next()
			return

	Logging.warn("pop_to_event: 未找到目标事件 '%s'，栈中无匹配条目" % event_key)


func _event_identity_matches(ev: BaseEvent, event_key: String) -> bool:
	"""判断一个 BaseEvent 是否匹配给定的 event_key"""
	if ev._namespace and event_key.begins_with(ev._namespace):
		return true
	return false


# --- Picker 栈条目生命周期 -----------------------------

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
		_process_stack()


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
		_process_stack()


func _show_focused_chat_from_stack(entry: Dictionary):
	# 纸带保持可见（作为背景上下文）
	_show_tape()

	_is_active = true
	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)
	Logging.info("FocusChat: pause_world 后 get_tree().paused=%s" % get_tree().paused)

	var data = entry.get("data")
	var context: Dictionary = entry.get("context", {})
	Logging.info("FocusChat 显示中（纸带内嵌模式）")

	get_parent().show()
	show()

	# 🚨 确保 EventUI 在 show() 后正确布局，防止点击穿透或偏移
	await get_tree().process_frame

	var chat_entry = event_ui.append_focus_chat_entry(data, context)
	chat_entry.dialogue_finished.connect(_on_focused_chat_finished.bind(chat_entry, entry), CONNECT_ONE_SHOT)


# --- Cinematic 栈条目 -----------------------------------

func _on_push_cinematic(texts: Array[String]):
	var entry := {
		"type": "cinematic",
		"texts": texts.duplicate(),
		"processed": false,
	}
	_event_stack.push_front(entry)
	Logging.info("Cinematic 已推入栈顶，%d 段文字" % texts.size())

	if not _is_active:
		_process_stack()


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


func _process_stack():
	if _is_active:
		return
	if _event_stack.size() > 0:
		var entry = _event_stack[0]
		if entry is Dictionary and entry.get("type") == "picker":
			# 纸带保持可见
			_show_tape()
			show()
			_show_picker_from_stack(entry)
		elif entry is Dictionary and entry.get("type") == "cinematic":
			# 纸带保持可见
			_show_tape()
			show()
			entry["processed"] = true
			_show_cinematic_from_stack(entry)
		elif entry is Dictionary and entry.get("type") == "focused_chat":
			entry["processed"] = true
			_show_focused_chat_from_stack(entry)
		else:
			_current_from_stack = true
			entry["processed"] = true
			apply_narrative(entry.data, entry.context)
	else:
		Logging.warn("_process_stack: 栈为空")


# 按优先级处理下一个事件：栈 (LIFO) > 队列 (FIFO)
func _process_next():
	if _is_active:
		return

	# 🚨 等待后台动画播完再处理下一个事件（callback 驱动，见 _on_animation_finished）
	if not _active_animations.is_empty():
		_waiting_for_animations = true
		return

	# 栈优先 (LIFO)
	if _event_stack.size() > 0:
		var entry = _event_stack[0]
		if entry is Dictionary and entry.get("type") == "picker":
			Logging.info("弹出栈中的下一个 Picker")
			_show_tape()
			show()
			_show_picker_from_stack(entry)
			return
		if entry is Dictionary and entry.get("type") == "cinematic":
			Logging.info("弹出栈中的下一个 Cinematic")
			entry["processed"] = true
			_show_tape()
			show()
			_show_cinematic_from_stack(entry)
			return
		if entry is Dictionary and entry.get("type") == "focused_chat":
			Logging.info("弹出栈中的下一个 FocusChat")
			entry["processed"] = true
			_show_focused_chat_from_stack(entry)
			return
		_current_from_stack = true
		var ev: BaseEvent = entry.get("data")
		var ctx: Dictionary = entry.get("context", {})
		Logging.info("弹出栈中的下一个事件: " + ev.name)
		apply_narrative(ev, ctx)
		return

	# 队列其次 (FIFO)
	if _event_queue.size() > 0:
		var entry = _event_queue.pop_front()
		_current_from_stack = false
		var next_event: BaseEvent = entry.get("data")
		var next_context: Dictionary = entry.get("context", {})
		Logging.info("弹出队列中的下一个事件: " + next_event.name)
		apply_narrative(next_event, next_context)
		return

	# 栈和队列全空 → 清空纸带，隐藏面板，清除模糊
	Logging.info("_process_next: 栈和队列全空，清空纸带并隐藏")
	BlurManager.return_to_hub()
	event_ui.clear_all_tape()
	get_parent().hide()
	hide()
	_tape_initialized = false


# --- Picker 局部压暗 ──────────────────────────────────

## 纸带历史降维：墨褪纸存 — 只褪文本标签颜色，纸张底色原封不动
##
## 原则：压暗的是「墨迹」（Label/RichTextLabel 的 modulate），
## 而不是「纸张」（PanelContainer/StyleBoxFlat 的背景）。
## 绝不使用黑色半透明 ColorRect 遮罩（那是 CIA 档案黑条 💀）。
const DIM_HISTORY_INK_COLOR: Color = Color(0.75, 0.62, 0.42, 0.35)


func _dim_tape_history(picker_node: Control) -> void:
	var tape: VBoxContainer = event_ui._tape_content
	if not tape:
		Logging.warn("_dim_tape_history: _tape_content 为空")
		return

	var dimmed_count := 0
	for child in tape.get_children():
		if child == picker_node:
			Logging.info("_dim_tape_history: 跳过 picker 节点 name='%s' class='%s'" % [child.name, child.get_class()])
			continue

		Logging.info("_dim_tape_history: 开始褪墨 entry name='%s' class='%s' child_count=%d" % [child.name, child.get_class(), child.get_child_count()])

		# 递归遍历历史条目内的所有 Label / RichTextLabel，直接设置 theme_override font_color
		var text_count := _dim_text_nodes_recursive(child)
		Logging.info("_dim_tape_history: entry '%s' 褪墨完成，共处理 %d 个文本节点" % [child.name, text_count])

		dimmed_count += 1
	Logging.info("_dim_tape_history: 历史条目文本已褪墨（%d 个 entry）" % dimmed_count)


## 递归遍历节点树，对所有 Label / RichTextLabel 直接设置 theme_override font_color
## 返回处理的文本节点数量
func _dim_text_nodes_recursive(node: Node) -> int:
	var count := 0
	for child_node in node.get_children():
		if child_node is Label or child_node is RichTextLabel:
			Logging.info("  _dim_text: 褪墨节点 name='%s' class='%s' path='%s' → font_color=%s text='%s'" % [
				child_node.name,
				child_node.get_class(),
				str(child_node.get_path()),
				str(DIM_HISTORY_INK_COLOR),
				child_node.text if child_node is Label else "(RichTextLabel)"
			])
			if child_node is Label:
				child_node.add_theme_color_override(&"font_color", DIM_HISTORY_INK_COLOR)
			elif child_node is RichTextLabel:
				child_node.add_theme_color_override(&"default_color", DIM_HISTORY_INK_COLOR)
			count += 1
		else:
			count += _dim_text_nodes_recursive(child_node)
	return count


func _undim_tape_history() -> void:
	var tape: VBoxContainer = event_ui._tape_content
	if not tape:
		Logging.warn("_undim_tape_history: _tape_content 为空")
		return

	# 递归恢复所有 Label / RichTextLabel 的 font_color 到默认
	var restored_count := 0
	for child in tape.get_children():
		Logging.info("_undim_tape_history: 开始恢复 entry name='%s' class='%s'" % [child.name, child.get_class()])
		var text_count := _undim_text_nodes_recursive(child)
		Logging.info("_undim_tape_history: entry '%s' 恢复完成，共处理 %d 个文本节点" % [child.name, text_count])
		restored_count += 1

	Logging.info("_undim_tape_history: 文本墨色已恢复（%d 个 entry）" % restored_count)


## 递归遍历节点树，移除所有 Label / RichTextLabel 的 theme_override font_color
## 返回处理的文本节点数量
func _undim_text_nodes_recursive(node: Node) -> int:
	var count := 0
	for child_node in node.get_children():
		if child_node is Label or child_node is RichTextLabel:
			Logging.info("  _undim_text: 恢复节点 name='%s' class='%s' → 移除 font_color override text='%s'" % [
				child_node.name,
				child_node.get_class(),
				child_node.text if child_node is Label else "(RichTextLabel)"
			])
			if child_node is Label:
				child_node.remove_theme_color_override(&"font_color")
			elif child_node is RichTextLabel:
				child_node.remove_theme_color_override(&"default_color")
			count += 1
		else:
			count += _undim_text_nodes_recursive(child_node)
	return count


# --- Picker 栈条目生命周期 -----------------------------

func _show_picker_from_stack(entry: Dictionary):
	_is_active = true
	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)

	# Picker 展示时：Layer 50 全屏毛玻璃渐入
	BlurManager.show_picker_blur()

	var data: Array = entry.get("data", [])
	var ui_constructor_raw = entry.get("ui_constructor")
	var ui_constructor: Callable = ui_constructor_raw if ui_constructor_raw != null else Callable()

	Logging.info("Picker 显示中（纸带内嵌模式），%d 个选项" % data.size())

	var attachment = event_ui.append_picker_attachment(data, ui_constructor)
	attachment.item_selected.connect(func(e): _on_picker_item_selected(e, attachment, entry), CONNECT_ONE_SHOT)

	# 局部压暗：纸带内历史条目褪入阴影，Picker 保持高光
	_dim_tape_history(attachment)


func _on_picker_item_selected(entity: Variant, _attachment, entry: Dictionary):
	if _event_stack.size() == 0:
		Logging.warn("_on_picker_item_selected: 栈为空，没有 picker 条目")
		return

	_event_stack.pop_front()
	Logging.info("Picker 已从栈中弹出，选择了: %s" % str(entity))

	# Picker 完成：Layer 50 毛玻璃渐出
	BlurManager.hide_picker_blur()

	# 恢复纸带历史亮度
	_undim_tape_history()

	var callback: Callable = entry.get("on_selected", Callable())
	if callback.is_valid():
		callback.call(entity)

	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	_is_active = false
	_process_next()


func _on_focused_chat_finished(result: ChoiceResult, _chat_entry, entry: Dictionary):
	_event_stack.pop_front()
	Logging.info("FocusChat 已从栈中弹出")

	if result:
		ConsequenceExecuter.execute_result(result)

	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	_is_active = false
	_process_next()


# --- Cinematic 栈条目生命周期 ---------------------------

func _show_cinematic_from_stack(entry: Dictionary):
	_is_active = true
	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)

	var texts: Array[String] = entry.get("texts", [])
	Logging.info("Cinematic 播放中，%d 段文字" % texts.size())

	EventBus.cinematic_start.emit(texts)
	await EventBus.cinematic_finished
	await BlurManager.trigger_cinematic_post_blur(3.0)

	_event_stack.pop_front()
	Logging.info("Cinematic 已从栈中弹出")

	# 纸带追加 stub 摘要
	var summary: String = "⚡ 过场动画"
	if texts.size() > 0:
		# 用第一段文字的前 20 个字符作为摘要
		var first := texts[0] as String
		if first.length() > 20:
			summary = "⚡ " + first.substr(0, 20) + "…"
		else:
			summary = "⚡ " + first
	event_ui.append_stub("cinematic", summary)

	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	_is_active = false
	_process_next()


# ═══════════════════════════════════════════════
# apply_narrative — 纸带模式核心
# ═══════════════════════════════════════════════

func apply_narrative(data: BaseEvent, context: Dictionary):
	# 如果已有事件在播放，入队等待
	if _is_active:
		_event_queue.append({ "data": data, "context": context })
		Logging.info("事件已入队等待: " + data.name)
		return

	# --- Pre-event Interruption Sequence ---
	if not _is_checking_interruption and data.has_method("check_interruption"):
		_is_checking_interruption = true
		data.check_interruption(context)
		_is_checking_interruption = false

		if _is_active:
			Logging.info("apply_narrative: 被中断序列替换，放弃当前事件 " + data.name)
			return

	# 先显示纸带面板（如果还没显示）
	# 🚨 如果纸带已有历史条目且背景纹理变化 → 抽纸动画清空条目后重新滑入
	if _needs_background_swap(data):
		await _perform_background_swap(data)
	else:
		_show_tape()
		# ── UIDecl 背景纹理动态替换 ──
		_apply_ui_decl_background(data)

	_is_active = true
	var all_options: Array = data.init(context)

	# ── 防御性检查：选项文本全空 → lasting_time 决定行为 ──
	# 数据错误（如 CSV 中 option 行 description 列漏填）会导致按钮无法生成 btn_id、
	# 文本为空、无法注册到 AncientOptionBtnManager，玩家无法选择。
	# lasting_time > 0：展示事件后自动关闭（不跳过）；lasting_time == 0：退化为直接跳过
	if _has_no_displayable_option(all_options):
		if data.lasting_time <= 0.0:
			Logging.err("apply_narrative: 事件 '%s' 的所有选项文本为空且 lasting_time=0，跳过该事件" % data.name)
			_is_active = false
			_process_next()
			return
		Logging.info("apply_narrative: 事件 '%s' 0 选项但 lasting_time=%.1f > 0，展示后自动关闭" % [data.name, data.lasting_time])

	EventBus.event_shown.emit(data)
	if data.epitaph_text:
		TimeService.register_to_master_timeline(data.time, data.name, data.epitaph_text)

	_saved_time_scale = Engine.time_scale
	TimeService.pause_world(true)
	current_event_data = data

	# 用 instance_id 作为纸带条目稳定标识符
	var entry_id := str(data.get_instance_id())

	# ── 分支：回归路径 vs 新事件路径 ──
	if event_ui.has_entry(entry_id):
		# === 回归路径（stack pop 后回归）===
		Logging.info("apply_narrative: 回归路径，复活 entry_id='%s'" % entry_id)
		BlurManager.trigger_event_blur()
		event_ui.clear_all_dim()
		event_ui.revive_entry(entry_id, all_options)
		event_ui.scroll_to_entry(entry_id)
		# 回归路径：同步完成，可启动 auto-advance
		if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
			_start_auto_advance(data.lasting_time, all_options, entry_id)
	else:
		# === 新事件路径 ===
		Logging.info("apply_narrative: 新事件路径，追加 entry_id='%s' from_stack=%s" % [entry_id, _current_from_stack])

		# dim 策略：queue 事件 dim 前序，stack 事件不 dim
		if not _current_from_stack:
			event_ui.dim_previous_entries()

		# ── 结算检测：结算事件走专用渲染路径，绕过打字机 ──
		if context.get("is_settlement", false):
			Logging.info("NarrativeOverlay.apply_narrative: 检测到结算事件，走专用渲染路径")
			BlurManager.show_picker_blur()
			_is_settlement = true
			event_ui.append_settlement_entry(data, context)
			# 结算不需要中断按钮
			_pending_interrupt_event_key = ""
			_pending_interrupt_context = {}
			_interrupt_button.get_parent().visible = false
			# 跳过 display_speed 路由，公共逻辑（register_scroll / AudioManager / scroll_to_bottom）在外部统一执行
		else:
			BlurManager.trigger_event_blur()
			# 根据显示速度路由
			match data.display_speed:
				BaseEvent.DisplaySpeed.SLOW:
					Logging.info("NarrativeOverlay.apply_narrative: SLOW 模式（event='%s'）" % data.name)
					event_ui.display_slow(data, all_options, context, _current_from_stack, entry_id, EventUI.SLOW_SPEED)
					# SLOW 模式：等待打字机全部完成后启动 auto-advance
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(data.lasting_time, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				BaseEvent.DisplaySpeed.SLOWEST:
					Logging.info("NarrativeOverlay.apply_narrative: SLOWEST 模式（event='%s'）" % data.name)
					event_ui.display_slow(data, all_options, context, _current_from_stack, entry_id, EventUI.SLOWEST_SPEED)
					# SLOWEST 模式：等待打字机全部完成后启动 auto-advance
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(data.lasting_time, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				_:
					Logging.info("NarrativeOverlay.apply_narrative: FAST 模式（event='%s'）" % data.name)
					event_ui.append_event_entry(data, all_options, context, _current_from_stack, entry_id)
					# FAST 模式：同步返回，直接启动 auto-advance
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						_start_auto_advance(data.lasting_time, all_options, entry_id)

	# ── 注册纸带滚动容器（供 PgUp/PgDn 翻页）──
	event_ui.register_scroll_for_input_manager()

	# ── UIDecl 自定义音频优先 ──
	if data.ui_decl and data.ui_decl.audio:
		AudioManager.play_music(data.ui_decl.audio)
	else:
		AudioManager.play_sad()

	# 扫描 context 中的 interrupt_event 字段，控制 ShadowBox 右侧 InterruptButton
	var interrupt_event_data = context.get("interrupt_event", null)
	Logging.info("NarrativeOverlay.apply_narrative: interrupt_event_data=%s, _interrupt_button=%s, _interrupt_button.parent=%s" % [interrupt_event_data, _interrupt_button, _interrupt_button.get_parent() if _interrupt_button else "(null)"])
	if interrupt_event_data is Dictionary:
		_pending_interrupt_event_key = interrupt_event_data.get("event_key", "")
		_pending_interrupt_context = context.duplicate(true)
		_pending_interrupt_context.erase("interrupt_event")
		if not _pending_interrupt_event_key.is_empty():
			# 按钮文本
			var btn_text: String = interrupt_event_data.get("text", "中断")
			_interrupt_button.get_node("Margin/Label").text = btn_text
			_interrupt_button.tooltip_text = btn_text
			# 按钮颜色：interrupt_event.color 或默认深红色
			var btn_color: Color = interrupt_event_data.get("color", Color(0.70, 0.15, 0.30))
			_interrupt_button.self_modulate = btn_color
			_interrupt_button.get_parent().visible = true
			Logging.info("NarrativeOverlay: 中断按钮已配置，目标事件='%s' text='%s'" % [_pending_interrupt_event_key, btn_text])
		else:
			_interrupt_button.get_parent().visible = false
			Logging.debug("NarrativeOverlay: interrupt_event 存在但 event_key 为空")
	else:
		_pending_interrupt_event_key = ""
		_pending_interrupt_context = {}
		_interrupt_button.get_parent().visible = false
		Logging.debug("NarrativeOverlay: context 中无 interrupt_event")

	# 滚动到底部
	event_ui.scroll_to_bottom()


# ═══════════════════════════════════════════════
# 选项选择与事件结束 — 纸带模式
# ═══════════════════════════════════════════════

## 检查选项数组中是否存在至少一个可显示的选项（文本非空）。
## 文本来源优先级：_resolved_description（动态解析后）> description（静态）。
## 全空返回 true，表示该事件无可显示选项，应跳过。
func _has_no_displayable_option(all_options: Array) -> bool:
	if all_options.is_empty():
		return true
	for o in all_options:
		if o == null:
			continue
		# 优先读取 _resolved_description（EventOption 的动态解析字段）
		if '_resolved_description' in o and o._resolved_description and not o._resolved_description.is_empty():
			return false
		# fallback 到 description
		if 'description' in o and o.description and not o.description.is_empty():
			return false
	return true


## 计數可显示选项数量（与 _has_no_displayable_option 同样逻辑，但返回 int）
func _count_displayable_options(all_options: Array) -> int:
	var count := 0
	for o in all_options:
		if o == null:
			continue
		if '_resolved_description' in o and not o._resolved_description.is_empty():
			count += 1
		elif 'description' in o and not o.description.is_empty():
			count += 1
	return count


## 取消自动推进计时器（玩家手动点选 / 中断时调用）
func _cancel_auto_advance() -> void:
	if _auto_advance_timer:
		_auto_advance_timer.queue_free()
		_auto_advance_timer = null
		Logging.info("NarrativeOverlay: auto-advance Timer 已取消")


## 启动自动推进计时器 — lasting_time 秒后自动选择选项或关闭事件
func _start_auto_advance(seconds: float, all_options: Array, entry_id: String) -> void:
	_cancel_auto_advance()
	_auto_advance_timer = Timer.new()
	_auto_advance_timer.wait_time = seconds
	_auto_advance_timer.one_shot = true
	_auto_advance_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_auto_advance_timer)
	_auto_advance_timer.timeout.connect(_on_auto_advance_timeout.bind(all_options, entry_id))
	_auto_advance_timer.start()
	Logging.info("NarrativeOverlay: auto-advance Timer 已启动（%.1f秒）entry_id='%s'" % [seconds, entry_id])


## Timer 到期回调 — 0 选项自动关闭 / 1 选项自动选择
func _on_auto_advance_timeout(all_options: Array, entry_id: String) -> void:
	_auto_advance_timer = null
	var displayable_count := _count_displayable_options(all_options)

	if displayable_count == 0:
		# 0 选项：静默关闭，不执行后果（类似中断，但不触发后续 push）
		Logging.info("NarrativeOverlay: auto-advance 到期，0选项 → 自动关闭 entry_id='%s'" % entry_id)
		event_ui.mark_chosen(entry_id, "[时尽]")
		TimeService.resume_world()
		Engine.time_scale = _saved_time_scale
		EventBus.event_confirmed.emit()
		if _event_stack.size() > 0:
			var top_entry = _event_stack[0]
			if top_entry.has("data") and top_entry.get("data") == current_event_data:
				_event_stack.pop_front()
				Logging.info("_on_auto_advance_timeout: 已弹出栈顶事件 '%s'" % current_event_data.name)
		_is_active = false
		_process_next()

	elif displayable_count == 1:
		# 1 选项：自动选择
		Logging.info("NarrativeOverlay: auto-advance 到期，1选项 → 自动选择 entry_id='%s'" % entry_id)
		var option = null
		for o in all_options:
			if o == null:
				continue
			if '_resolved_description' in o and not o._resolved_description.is_empty():
				option = o
				break
			if 'description' in o and not o.description.is_empty():
				option = o
				break
		if option:
			var choice_result = option.get("choice_result") if option else null
			var choice_text = event_ui._find_option_text(all_options, choice_result) if choice_result else "[自动]"
			_on_option_selected(choice_result, choice_text)
		else:
			Logging.err("NarrativeOverlay: auto-advance 到期但无法找到可显示选项，entry_id='%s'" % entry_id)


func _on_option_selected(_choice_result, _choice_text: String = ""):
	_cancel_auto_advance()  # 玩家手动点击 → 取消自动推进
	_end_narrative(_choice_result, _choice_text)


func _end_narrative(choice, choice_text: String = ""):
	_cancel_auto_advance()  # 防御性取消：确保无论哪个入口都不会残留 Timer
	# 纸带模式：不退场、不 hide()，选项变文本烙印留在纸带上
	var entry_id := str(current_event_data.get_instance_id())
	event_ui.mark_chosen(entry_id, choice_text)

	# ── 结算面板：清除 Picker 式全屏高斯模糊 ──
	if _is_settlement:
		BlurManager.hide_picker_blur()
		_is_settlement = false

	# 恢复世界
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	Logging.done('narrative finished')
	EventBus.event_confirmed.emit()

	var _completed_data: BaseEvent = current_event_data
	await ConsequenceExecuter.execute_result(choice)

	# 🚩 守卫：处理 execute_result 期间可能激活的栈条目
	if _event_stack.size() > 0 and _event_stack[0].get("processed", false):
		var guard_entry = _event_stack[0]
		var entry_type = guard_entry.get("type", "")

		# 分支 A: 当前事件自身在栈上的条目 → 正常弹出
		if guard_entry.get("data") == _completed_data:
			_event_stack.pop_front()
			Logging.info("_end_narrative: 自动弹出已完成的栈事件 '%s'" % _completed_data.name)

		# 分支 B: execute_result 期间 FocusChat/Picker/Cinematic 被激活
		elif entry_type in ["focused_chat", "picker", "cinematic"]:
			Logging.info("_end_narrative: 栈顶条目已处理（如 FocusChat 已显示），跳过 _is_active 重置")
			return

		# 分支 C: 未知类型（防御性）
		else:
			Logging.warn("_end_narrative: 栈顶存在未知类型条目 type='%s'，强制弹出" % entry_type)
			_event_stack.pop_front()

	_is_active = false
	_process_next()


# --- 中断按钮处理（纸带模式）----------------------------

func _on_interrupt_pressed() -> void:
	_cancel_auto_advance()  # 中断 = 用户主动退出，停掉所有自动推进
	if not _is_active:
		Logging.warn("NarrativeOverlay._on_interrupt_pressed: 非活跃状态，忽略重复点击")
		return

	Logging.info("NarrativeOverlay._on_interrupt_pressed: 中断按钮被点击，目标事件='%s'" % _pending_interrupt_event_key)

	# 纸带模式：不退场、不 hide()，当前条目标记为已中断，隐藏按钮
	_interrupt_button.get_parent().visible = false

	var entry_id := str(current_event_data.get_instance_id())
	event_ui.mark_chosen(entry_id, "[中断]")
	Logging.info("NarrativeOverlay._on_interrupt_pressed: 跳过 execute_result，不执行当前事件结果")

	# 恢复世界时间
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	EventBus.event_confirmed.emit()

	# 如果当前事件在栈顶 → pop 掉
	if _event_stack.size() > 0:
		var top_entry = _event_stack[0]
		if top_entry.has("data") and top_entry.get("data") == current_event_data:
			_event_stack.pop_front()
			Logging.info("_on_interrupt_pressed: 已弹出栈顶事件 '%s'" % current_event_data.name)
		else:
			Logging.info("_on_interrupt_pressed: 当前事件不在栈顶，不操作栈")
	else:
		Logging.info("_on_interrupt_pressed: 栈为空，不操作栈")

	var target_event_key := _pending_interrupt_event_key
	var target_context := _pending_interrupt_context
	_pending_interrupt_event_key = ""
	_pending_interrupt_context = {}

	_is_active = false

	if not target_event_key.is_empty():
		EventBus.push_event.emit(target_event_key, target_context)
		Logging.info("_on_interrupt_pressed: 目标事件 '%s' 已入栈" % target_event_key)

	Logging.info("_on_interrupt_pressed: 中断流程完成，处理下一个事件")
	_process_next()


# --- 动画追踪 ------------------------------------------

func track_animation(anim: AnimationObject) -> void:
	if anim.finished.is_connected(_on_animation_finished.bind(anim)):
		return
	_active_animations.append(anim)
	anim.finished.connect(_on_animation_finished.bind(anim), CONNECT_ONE_SHOT)
	anim.start()


func _on_animation_finished(anim: AnimationObject) -> void:
	_active_animations.erase(anim)
	if _waiting_for_animations and _active_animations.is_empty():
		_waiting_for_animations = false
		_process_next()

# ── UIDecl 背景纹理动态替换 ──────────────────────

## 根据事件的 ui_decl.background_narrative 动态替换 NarrativeOverlay 纸带的
## StyleBoxTexture 背景纹理。ui_decl 为空或 background_narrative 为空时保持默认宣纸纹理。
func _apply_ui_decl_background(data: BaseEvent) -> void:
	if not data.ui_decl:
		return
	var ui_decl: UIDecl = data.ui_decl
	if not ui_decl.background_narrative:
		return
	# NarrativeOverlay 自身的 theme_override_styles/panel 是 StyleBoxTexture
	var style: StyleBoxTexture = get("theme_override_styles/panel") as StyleBoxTexture
	if not style:
		Logging.warn("NarrativeOverlay._apply_ui_decl_background: 无法获取 StyleBoxTexture panel style")
		return
	style.texture = ui_decl.background_narrative
	Logging.info("NarrativeOverlay._apply_ui_decl_background: event='%s' 背景纹理已替换" % data.name)


# ── 背景纹理交换检测 ────────────────────────────

## 判断是否需要「抽纸动画」：纸带上有历史条目 且 新事件带了不同的背景纹理。
## @return: true → 需要抽上去清空条目再抽下来；false → 正常流程
func _needs_background_swap(data: BaseEvent) -> bool:
	# 条件 1：纸带上必须有历史条目
	var history_child_count: int = event_ui._tape_content.get_child_count()
	if history_child_count <= 0:
		Logging.info("_needs_background_swap: 纸带无历史条目，无需交换背景")
		return false

	# 条件 2：新事件必须声明了 background_narrative
	if not data.ui_decl or not data.ui_decl.background_narrative:
		Logging.info("_needs_background_swap: 事件 '%s' 未声明 background_narrative，无需交换背景" % data.name)
		return false

	# 条件 3：新纹理 ≠ 当前纹理
	var style: StyleBoxTexture = get("theme_override_styles/panel") as StyleBoxTexture
	if not style:
		Logging.info("_needs_background_swap: 无法获取当前 StyleBoxTexture，跳过交换")
		return false

	var current_texture: Texture2D = style.texture
	var new_texture: Texture2D = data.ui_decl.background_narrative
	if current_texture == new_texture:
		Logging.info("_needs_background_swap: 背景纹理未变化（%s），无需交换" % current_texture.resource_path if current_texture else "(null)")
		return false

	Logging.info("_needs_background_swap: 检测到背景变化 '%s' → '%s'，触发抽纸动画" % [
		current_texture.resource_path if current_texture else "(null)",
		new_texture.resource_path if new_texture else "(null)"
	])
	return true


# ── 抽纸动画：背景交换专用 ────────────────────────

## 纸带有历史条目 + 背景纹理变化时执行：
##   1. ShadowBox 向上滑出屏幕（CUBIC EASE_IN，0.5s）
##   2. 清空纸带所有条目
##   3. 重置 _tape_initialized 状态
##   4. 应用新背景纹理
##   5. 调用 _show_tape() 标准滑入
##
## ⚠️ 这是一个 async 方法，调用方必须 await
func _perform_background_swap(data: BaseEvent):
	var shadow := get_parent()
	var viewport_height := get_viewport_rect().size.y

	Logging.info("_perform_background_swap: 开始抽纸动画 — 当前 pos.y=%s, 历史条目数=%d" % [
		shadow.position.y, event_ui._tape_content.get_child_count()
	])

	# ── 1. 杀死所有活跃 Tween，防止干扰 ──
	if _tween:
		_tween.kill()
		_tween = null

	# ── 2. 向上滑出：target = 屏幕顶部外 ──
	var slide_out_target := -(viewport_height + 100.0)
	var slide_out_duration := 0.5
	var slide_out_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide_out_tween.tween_property(shadow, "position:y", slide_out_target, slide_out_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# 同步淡出透明度
	slide_out_tween.set_parallel(true)
	slide_out_tween.tween_property(self, "modulate:a", 0.0, slide_out_duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	Logging.info("_perform_background_swap: 滑出动画中... target=%s, duration=%s" % [slide_out_target, slide_out_duration])
	await slide_out_tween.finished
	Logging.info("_perform_background_swap: 滑出完成")

	# ── 3. 清空纸带所有历史条目 ──
	event_ui.clear_all_tape()
	Logging.info("_perform_background_swap: 纸带条目已清空")

	# ── 4. 重置 _tape_initialized，让 _show_tape 重新播放完整动画 ──
	_tape_initialized = false

	# ── 5. 应用新背景纹理 ──
	_apply_ui_decl_background(data)

	# ── 6. 标准滑入动画 ──
	_show_tape()
	# 等待滑入完成（Tween 时长 0.65s）
	if _tween:
		await _tween.finished
	Logging.info("_perform_background_swap: 抽纸动画完成，新背景已就位")
