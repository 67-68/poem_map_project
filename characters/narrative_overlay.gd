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
var _event_stack: Array[Dictionary] = []

var _is_active: bool = false
var _current_from_stack: bool = false
var _saved_time_scale: float = 1.0

# 引用 imaginary_manager
@onready var imaginary_manager = get_node("/root/Main/CoreSystems/ImagenaryManager")

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

# ─── 事件栈处理 ───────────────────────────────────────

func _on_push_event(data: Variant, context: Dictionary):
	var ev = _resolve_event_for_stack(data)
	if not ev:
		return

	# 🔒 防御性深拷贝：栈中的 context 必须是完全隔离的快照
	# 契约：调用方（PushEventOperator等）负责提供独立 context，
	# 但这里做二次防御，防止其他 emit push_event 的路径忘记 duplicate
	_event_stack.push_front({ "data": ev, "context": context.duplicate(true) })
	Logging.info("事件已推入栈: " + ev.name)

	if not _is_active:
		_process_stack()


func _on_pop_event():
	if _event_stack.size() > 0:
		var entry = _event_stack.pop_front()
		var ev: BaseEvent = entry.get("data")
		Logging.info("pop_event: 弹出栈事件 - " + ev.name)
	else:
		Logging.warn("pop_event: 栈为空，忽略")
		return

	if not _is_active:
		_process_next()


# 将 data（BaseEvent 或 String key）解析为 BaseEvent
func _resolve_event_for_stack(data: Variant) -> BaseEvent:
	if data is BaseEvent:
		return data
	if data is String:
		var ev = Database.history_events.get(data)
		if not ev: ev = Database.normal_poem_events.get(data)
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
	if _event_stack.size() > 0:
		# peek 不移除，留待 PopEventOperator 显式 pop
		var entry = _event_stack[0]
		_current_from_stack = true
		apply_narrative(entry.data, entry.context)
	else:
		Logging.warn("_process_stack: 栈为空")


# 按优先级处理下一个事件：栈 (LIFO) > 队列 (FIFO)
func _process_next():
	# 栈优先 (LIFO) — peek 不移除，留待 PopEventOperator 显式 pop
	if _event_stack.size() > 0:
		var entry = _event_stack[0]
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


func apply_narrative(data: BaseEvent, context: Dictionary):
	# 如果已有事件在播放，入队等待
	if _is_active:
		_event_queue.append({ "data": data, "context": context })
		Logging.info("事件已入队等待: " + data.name)
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
	$Background/Margin/VBox/ContentLabel.text = data.description
	$Background/Margin/VBox/ExampleLabel.text = data.example # 比如诗词原文

	# 使用 init() 返回的全量选项（含 provider 动态生成的），而非 data.options（仅静态选项）
	$Background/Margin/VBox/OptionBtns.apply_btns(all_options, _on_option_selected)

	AudioManager.play_sad()

	# 5. 🎬 进场动画 (The Entrance)
	_play_open_animation()

func _on_option_selected(_choice_result):
	# 这里可以加个逻辑：记录玩家的选择，或者处理 disabled 选项的拒绝音效
	# 如果是有效选择，关闭界面
	_end_narrative(_choice_result)

func _end_narrative(choice):
	# 1. 🎬 退场动画 (The Exit)
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
	_is_active = false
	Logging.done('narrative finished')
	EventBus.event_confirmed.emit() # 绑定事件系统信号

	# 🔒 快照当前事件数据，防止 execute_result 期间触发新事件覆盖 current_event_data
	# 注意：ConsequenceExecuter.execute_result 可能同步触发 apply_narrative 设置新的
	# current_event_data，所以必须在 execute_result 之前快照。
	# 同时，不能在这里设置 current_event_data = null，因为 execute_result 触发的
	# 新事件正在显示中，其 _end_narrative 需要读取 current_event_data。
	# current_event_data 会在下一次 apply_narrative 时被自然覆盖。
	var _completed_data: BaseEvent = current_event_data
	ConsequenceExecuter.execute_result(choice)

	# 在执行后果后进行 imaginary 判定，确保 emotion 已被修改
	imaginary_manager.add_imagenary(_completed_data)

	# 处理后续事件：栈 (LIFO) 优先，队列 (FIFO) 次之
	_process_next()
