class_name NarrativeOverlay extends Control

# 引用子节点 (根据上面的新结构调整路径)
@onready var main_card: TextureRect = $Background
@onready var dimmer: ColorRect = $Dimmer
@onready var btn_container: VBoxContainer = $Background/Margin/VBox/OptionBtns

# 状态
var current_event_data: BaseEvent
var _tween: Tween

# 事件队列 (FIFO)，防止多个事件相互覆盖
# 每个元素为 { "data": BaseEvent, "context": Dictionary }
var _event_queue: Array[Dictionary] = []

# 事件栈 (LIFO)，优先级高于普通队列
# 栈中的事件会先于队列处理；栈空时才处理队列
# 支持两种条目类型：
#   - BaseEvent 条目: { "data": BaseEvent, "context": Dictionary }
#   - Picker 条目:    { "type": "picker", "data": Array, "on_selected": Callable, "ui_constructor": Callable }
var _event_stack: Array[Dictionary] = []

var _is_active: bool = false
# 中断检查递归保护：阻止 check_interruption -> push_event -> apply_narrative 无限循环
var _is_checking_interruption: bool = false
var _current_from_stack: bool = false
var _saved_time_scale: float = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	EventBus.request_event.connect(func(data, _context): apply_narrative(data, _context))
	EventBus.request_event_key.connect(func(key, _context):
		var ev = Database.history_events.get(key)
		if not ev: ev = Database.normal_poem_events.get(key)
		if not ev: ev = Database.find_triggerable_item(key)
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
	EventBus.push_picker.connect(_on_push_picker)
	EventBus.end_picking.connect(_on_end_picking)
	EventBus.push_cinematic.connect(_on_push_cinematic)

	# 确保这玩意在暂停时也能点
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _play_open_animation():
	if _tween: _tween.kill()
	# 必须显式声明 Tween 的 Pause 模式，以防被 TimeService 杀掉
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 修正中心点，确保缩放动画是从屏幕中央弹出的 (假设你的锚点是全屏)
	main_card.pivot_offset = main_card.size / 2.0

	show()

	# A. 遮罩变暗 (确保 Dimmer 基础颜色是不透明的黑！)
	dimmer.modulate.a = 0.0
	_tween.tween_property(dimmer, "modulate:a", 1.0, 0.5)

	# B. 卡片弹出 (从小变大 + 透明度)
	main_card.scale = Vector2(0.8, 0.8)
	main_card.modulate.a = 0.0
	_tween.tween_property(main_card, "scale", Vector2(1.0, 1.0), 0.5)
	_tween.tween_property(main_card, "modulate:a", 1.0, 0.3)

# --- 事件栈处理 ----------------------------------------

func _on_push_event(data: Variant, context: Dictionary):
	var ev = _resolve_event_for_stack(data)
	if not ev:
		return

	# 🚨 检查目标事件的 entry requirement
	# 防止 interruption 无条件 push 一个 entry condition 不满足的事件
	# （例如 flag_libai_changhe_request >= 1 时仍 push request_libai_changhe）
	if ev is RandomEvent and ev.requirement:
		ev.requirement.init(context)
		if not ev.requirement.compare(PlayerState):
			Logging.warn("push_event: 事件 '%s' 的 entry requirement 未通过，忽略 push" % ev.name)
			return

	# 防御性深拷贝：栈中的 context 必须是完全隔离的快照
	# 契约：调用方（PushEventOperator等）负责提供独立 context，
	# 但这里做二次防御，防止其他 emit push_event 的路径忘记 duplicate
	_event_stack.push_front({ "data": ev, "context": context.duplicate(true), "processed": false })
	Logging.info("事件已推入栈: " + ev.name)

	if not _is_active:
		_process_stack()


func _on_pop_event():
	if _event_stack.size() > 0:
		var entry = _event_stack.pop_front()
		# Picker 条目没有 "data" 字段（只有 BaseEvent 条目有）
		if entry.has("data"):
			var ev: BaseEvent = entry.get("data")
			if not entry.get("processed", false):
				Logging.err("pop_event: 事件 '%s' 被弹出但从未被处理过！可能存在事件丢失" % ev.name)
			Logging.info("pop_event: 弹出栈事件 - " + ev.name)
		else:
			Logging.info("pop_event: 弹出栈条目")
	else:
		Logging.warn("pop_event: 栈为空，忽略")
		return

	if not _is_active:
		_process_next()


func _on_pop_to_event(event_key: String):
	"""
	根据事件 ID 在栈中查找并弹出到对应层级。
	
	搜索顺序：从栈顶（index 0）向栈底遍历。
	跳过 picker 条目（type == "picker"），只匹配 BaseEvent 条目。
	匹配条件：entry.data.uuid == event_key 或 entry.data.name == event_key
	
	分支逻辑：
	- ✅ 找到目标事件 → 弹出目标事件之上的所有条目，目标事件留在栈顶
	   （标记 processed = false，使 _process_next 可以重新展示）
	- ❌ 未找到目标事件 → Logging.err + 无效果（不修改栈）
	"""
	var found_index = -1
	for i in range(_event_stack.size()):
		var entry = _event_stack[i]
		# 跳过 picker 条目（没有 "data" 字段的 BaseEvent）
		if entry is Dictionary and entry.get("type") == "picker":
			continue
		var ev: BaseEvent = entry.get("data")
		if ev and (ev.uuid == event_key or ev.name == event_key):
			found_index = i
			break

	if found_index == -1:
		Logging.err("pop_to_event: 事件 '%s' 未在栈中找到，忽略" % event_key)
		return

	# 弹出目标事件之上的所有条目（index 0 到 found_index - 1）
	# 目标事件本身保留在栈顶，以便 _process_next 重新展示
	for i in range(found_index):
		var entry = _event_stack.pop_front()
		if entry.has("data"):
			var ev: BaseEvent = entry.get("data")
			if not entry.get("processed", false):
				Logging.warn("pop_to_event: 事件 '%s' 被弹出但从未被处理过！" % ev.name)
			Logging.info("pop_to_event: 弹出栈事件 - " + ev.name)
		else:
			Logging.info("pop_to_event: 弹出栈条目（picker等）")

	# 目标事件现在在栈顶（index 0）
	# 重置 processed 标记，使其可以被 _process_next 重新展示
	if _event_stack.size() > 0:
		_event_stack[0]["processed"] = false
		Logging.info("pop_to_event: 已弹出到事件 '%s'，准备重新展示" % event_key)

	# 如果不处于活跃状态，处理下一个事件
	if not _is_active:
		_process_next()


# --- Picker 栈条目 -------------------------------------

func _on_push_picker(data: Array, on_selected: Callable, ui_constructor = null):
	var entry := {
		"type": "picker",
		"data": data.duplicate(),
		"on_selected": on_selected,
		"ui_constructor": ui_constructor,
	}
	_event_stack.push_front(entry)
	Logging.info("Picker 已推入栈顶，可选 %d 项" % data.size())

	# 此时可能在 _end_narrative 的 execute_result 调用链中，
	# 不要立即 _process_stack——等 _end_narrative 自然走到 _process_next
	if not _is_active:
		_process_stack()


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


# 将 data（BaseEvent 或 String key）解析为 BaseEvent
func _resolve_event_for_stack(data: Variant) -> BaseEvent:
	if data is BaseEvent:
		return data
	if data is String:
		var ev = Database.history_events.get(data)
		if not ev: ev = Database.normal_poem_events.get(data)
		if not ev: ev = Database.decided_events.get(data)
		if not ev: ev = Database.find_triggerable_item(data)
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
		# peek 不移除，留待 PopEventOperator 显式 pop / Picker 自行 pop
		var entry = _event_stack[0]
		if entry is Dictionary and entry.get("type") == "picker":
			_show_picker_from_stack(entry)
		elif entry is Dictionary and entry.get("type") == "cinematic":
			entry["processed"] = true
			_show_cinematic_from_stack(entry)
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
	# 栈优先 (LIFO) — peek 不移除，留待 PopEventOperator 显式 pop / Picker 自行 pop
	if _event_stack.size() > 0:
		var entry = _event_stack[0]
		if entry is Dictionary and entry.get("type") == "picker":
			Logging.info("弹出栈中的下一个 Picker")
			_show_picker_from_stack(entry)
			return
		if entry is Dictionary and entry.get("type") == "cinematic":
			Logging.info("弹出栈中的下一个 Cinematic")
			entry["processed"] = true
			_show_cinematic_from_stack(entry)
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


# --- Picker 栈条目生命周期 -----------------------------

func _show_picker_from_stack(entry: Dictionary):
	_is_active = true
	_saved_time_scale = Engine.time_scale
	# 像事件一样暂停世界——picker 本质上就是换了壳的事件
	TimeService.pause_world(true)

	var data: Array = entry.get("data", [])
	var ui_constructor = entry.get("ui_constructor", null)

	Logging.info("Picker 显示中，%d 个选项" % data.size())
	EventBus.start_picker.emit(data, ui_constructor)
	# 不再 await end_picking —— picker 完成由 _on_end_picking 信号处理器接管


func _on_end_picking(entity: Variant):
	# 从栈顶找到 picker 条目
	if _event_stack.size() == 0:
		Logging.warn("_on_end_picking: 栈为空，没有 picker 条目")
		return
	var entry = _event_stack[0]
	if not (entry is Dictionary and entry.get("type") == "picker"):
		Logging.warn("_on_end_picking: 栈顶不是 picker 条目，忽略")
		return

	# 弹出 picker 条目
	_event_stack.pop_front()
	Logging.info("Picker 已从栈中弹出")

	# 执行选择后的逻辑（accepted / rejected / not_entered 等）
	var callback: Callable = entry.get("on_selected", Callable())
	if callback.is_valid():
		callback.call(entity)

	# 🚩 注意：不自动 pop 触发 picker 的源事件
	# picker 只是临时挂起的模态层，源事件仍在栈顶被 peek，
	# 弹出 picker 后，源事件会通过 _process_next() 重新展示。
	# 源事件的后续生命周期由其自身的 PopEventOperator 管理。

	# 像事件一样恢复世界
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	_is_active = false
	# 处理下一个栈/队列事件
	_process_next()


# --- Cinematic 栈条目生命周期 ---------------------------

func _show_cinematic_from_stack(entry: Dictionary):
	_is_active = true
	_saved_time_scale = Engine.time_scale
	# 像事件/Picker 一样暂停世界
	TimeService.pause_world(true)

	var texts: Array[String] = entry.get("texts", [])
	Logging.info("Cinematic 播放中，%d 段文字" % texts.size())

	# 触发 CinematicOverlay 播放
	EventBus.cinematic_start.emit(texts)

	# 等待过场播完
	await EventBus.cinematic_finished

	# 弹出栈
	_event_stack.pop_front()
	Logging.info("Cinematic 已从栈中弹出")

	# 恢复世界
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	_is_active = false
	# 处理下一个栈/队列事件
	_process_next()


func apply_narrative(data: BaseEvent, context: Dictionary):
	# 如果已有事件在播放，入队等待
	if _is_active:
		_event_queue.append({ "data": data, "context": context })
		Logging.info("事件已入队等待: " + data.name)
		return

	# --- Pre-event Interruption Sequence（一层递归保护）---
	# 在事件 init 之前执行前置中断序列。
	# 如果 check_interruption 中的 operator push 了替代事件到栈，
	# _on_push_event 会同步触发 _process_stack -> 嵌套 apply_narrative。
	# _is_checking_interruption 阻止这种嵌套的无限递归（仅允许一层）。
	if not _is_checking_interruption and data.has_method("check_interruption"):
		_is_checking_interruption = true
		data.check_interruption(context)
		_is_checking_interruption = false

		# 中断序列 push 了事件到栈 -> 让栈事件替代当前事件
		if _is_active:
			Logging.info("apply_narrative: 被中断序列替换，放弃当前事件 " + data.name)
			return

	_is_active = true
	# data.init() 返回合并了 provider 动态生成的选项的全量数组
	var all_options: Array = data.init(context)
	EventBus.event_shown.emit(data)
	if data.epitaph_text:
		TimeService.register_to_master_timeline(data.time, data.name, data.epitaph_text)

	# 1. 保存当前时间流速并彻底暂停世界
	_saved_time_scale = Engine.time_scale
	# 在暂停之前切换
	#EventBus.request_change_bg_modulate.emit(data.color)
	TimeService.pause_world(true)
	current_event_data = data

	# 3. 填充内容
	$Background.texture = data.icon # 假设这是插画
	$Background/Margin/VBox/TitleLabel.text = data.name
	# 🚨 使用 tr_and_resolve 解析 description 中的 {@context_key} 模板插值
	# on_enter 阶段已将动态内容写入 context，此时 data.description 中的
	# {@keyword}、{@imaginary_desc}、{@npc_report} 等占位符
	# 会被替换为 context 中的实际值。
	$Background/Margin/VBox/ContentLabel.text = Util.tr_and_resolve(data.description, context, data)
	$Background/Margin/VBox/ExampleLabel.text = data.example # 比如诗词原文

	# 使用 init() 返回的全量选项（含 provider 动态生成的），而非 data.options（仅静态选项）
	$Background/Margin/VBox/OptionBtns.apply_btns(all_options, _on_option_selected)

	AudioManager.play_sad()

	# 5. 进场动画 (The Entrance)
	_play_open_animation()

func _on_option_selected(_choice_result):
	# 这里可以加个逻辑：记录玩家的选择，或者处理 disabled 选项的拒绝音效
	# 如果是有效选择，关闭界面
	_end_narrative(_choice_result)

func _end_narrative(choice):
	# 1. 退场动画 (The Exit)
	EventBus.request_restore_bg_modulate.emit(-1)
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# 反向操作
	_tween.tween_property(dimmer, "modulate:a", 0.0, 0.3)
	_tween.tween_property(main_card, "scale", Vector2(0.9, 0.9), 0.3)
	_tween.tween_property(main_card, "modulate:a", 0.0, 0.3)

	# 等动画播完再执行逻辑！
	await _tween.finished

	hide()

	# 3. 恢复世界 (以及之前保存的时间流速)
	TimeService.resume_world()
	Engine.time_scale = _saved_time_scale
	# 🚩 _is_active 保持 true，防止 execute_result 期间的 push_picker/push_event
	# 触发 _process_stack 导致栈事件被中途处理（与 operator 迭代产生竞态）
	Logging.done('narrative finished')
	EventBus.event_confirmed.emit() # 绑定事件系统信号

	# 快照当前事件数据，防止 execute_result 期间触发新事件覆盖 current_event_data
	# 注意：ConsequenceExecuter.execute_result 可能同步触发 apply_narrative 设置新的
	# current_event_data，所以必须在 execute_result 之前快照。
	# 同时，不能在这里设置 current_event_data = null，因为 execute_result 触发的
	# 新事件正在显示中，其 _end_narrative 需要读取 current_event_data。
	# current_event_data 会在下一次 apply_narrative 时被自然覆盖。
	var _completed_data: BaseEvent = current_event_data
	await ConsequenceExecuter.execute_result(choice)

	# 🚩 execute_result 完成后才释放 _is_active，避免 operator 迭代中途
	# push_picker/push_event 误触 _process_stack
	_is_active = false

	# 处理后续事件：栈 (LIFO) 优先，队列 (FIFO) 次之
	_process_next()
