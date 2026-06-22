class_name NarrativeOverlay extends PanelContainer

# 纸带模式（极乐迪斯科式）：NarrativeOverlay 不再是一次性弹窗，
# 而是持续的追加式事件纸带。纸带全空时才 hide()。
#
# 架构：NarrativeOverlay 是纯渲染门面，Director 管状态机/栈/队列，
# Visualizer 管 Tween 动画/墨迹 dim/undim。
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

# ── 子节点引用 ────────────────────────────────────
@onready var director: NarrativeDirector = $NarrativeDirector
@onready var visualizer: TapeVisualizer = $TapeVisualizer
# 🚨 event_ui 不写类型注解：class_name EventUI 在 parse 时尚未注册
@onready var event_ui = $TapeContainer/EventHistory
@onready var _interrupt_button: Button = $InterruptButton/Button
@onready var tape_container: PanelContainer = $TapeContainer

# ── Overlay 本地状态（仅 UI 相关）────────────────────
var current_event_data: BaseEvent
var _auto_advance_timer: Timer = null
var _is_settlement: bool = false
var _default_background_texture: Texture2D  # tscn 中 tape_container 的初始宣纸纹理
var _overlay_anim_in_progress: bool = false  # overlay 动画进行中，阻止 tape_needs_hide
var _deferred_hide_pending: bool = false     # 动画期间收到 hide 请求，动画完成后执行

# ═══════════════════════════════════════════════════
# _ready() — 信号接线
# ═══════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ── 配置 TapeVisualizer 的 export 引用（动态注入，避免 tscn 硬编码 uid）──
	visualizer.shadow_box = self               # NarrativeOverlay 自身即外层容器
	visualizer.tape_container = tape_container  # TapeContainer 内层纸纹理
	visualizer.tape_content = event_ui._tape_content  # VBoxContainer 纸带内容

	# ── 缓存默认背景纹理（tscn 中 tape_container 初始的宣纸纹理）──
	var default_style := tape_container.get("theme_override_styles/panel") as StyleBoxTexture
	if default_style:
		_default_background_texture = default_style.texture
		Logging.info("NarrativeOverlay._ready: 默认背景纹理已缓存 '%s'" % _default_background_texture.resource_path)
	else:
		Logging.warn("NarrativeOverlay._ready: 无法缓存默认背景纹理，tape_container panel 不是 StyleBoxTexture")

	# ── StyleManager: 注册 tape_container 并绑定 frost 策略 ──
	_bind_frost_strategy()

	# ── Director → 渲染层 ──
	director.tape_needs_show.connect(visualizer.play_show_tape)
	director.tape_needs_hide.connect(_on_hide_requested)
	director.event_ready_to_play.connect(_on_event_ready_to_play)
	director.picker_ready.connect(_on_picker_ready)
	director.cinematic_ready.connect(_on_cinematic_ready)
	director.focused_chat_ready.connect(_on_focused_chat_ready)
	director.interrupt_available.connect(_on_interrupt_available)
	director.interrupt_unavailable.connect(_on_interrupt_unavailable)
	director.pop_return_text_ready.connect(_on_pop_return_text_ready)
	director.pop_invalidate_parent.connect(_on_pop_invalidate_parent)

	# ── Overlay → Director ──
	# event_ui.option_selected → 先做 UI 清理再转发
	event_ui.option_selected.connect(_on_event_ui_option_selected)
	# 中断按钮 → 先做 UI 标记再转发
	_interrupt_button.pressed.connect(_on_interrupt_button_pressed)

	# ── EventBus → Overlay 动画请求 ──
	EventBus.request_overlay_animation.connect(_on_overlay_animation_requested)
	# ── TapeVisualizer → 动画完成回调 ──
	visualizer.overlay_animation_finished.connect(_on_overlay_animation_completed)

	Logging.info("NarrativeOverlay._ready: 信号接线完成")


# ═══════════════════════════════════════════════════
# 核心：事件入场装配
# ═══════════════════════════════════════════════════

func _on_event_ready_to_play(entry: Dictionary, from_stack: bool) -> void:
	var data: BaseEvent = entry.get("data")
	var context: Dictionary = entry.get("context", {})

	# ── 事件入场装配（从原 apply_narrative 迁出）──
	var all_options: Array = data.init(context)

	# 防御性检查：0 选项 + lasting_time=0 → 跳过
	if _has_no_displayable_option(all_options):
		if data.lasting_time <= 0.0:
			Logging.err("_on_event_ready_to_play: 事件 '%s' 所有选项文本为空且 lasting_time=0，跳过" % data.name)
			director.on_option_selected(null, "[跳过]")
			return
		Logging.info("_on_event_ready_to_play: 事件 '%s' 0 选项但 lasting_time=%.1f > 0" % [data.name, data.lasting_time])

	EventBus.event_shown.emit(data)
	if data.epitaph_text:
		TimeService.register_to_master_timeline(data.time, data.name, data.epitaph_text)

	current_event_data = data
	var entry_id := str(data.get_instance_id())

	# ── 背景交换判断（Overlay 决策，不是 Director）──
	if _needs_background_swap(data):
		# 通过回调注入清空条目 + 应用新纹理
		await visualizer.play_swap_background(
			data.ui_decl.background_narrative,
			func():
				event_ui.clear_all_tape()
				_apply_ui_decl_background(data)
		)
	else:
		# ── 动画策略路由 ──
		if data.ui_decl and data.ui_decl.animation_strategy == ENUMS.ANIMATION_STRATEGY.SLIDE_FROM_BOTTOM:
			visualizer.play_show_tape_from_bottom()
		else:
			visualizer.play_show_tape()
		_apply_ui_decl_background(data)

	# ── 分支：回归路径 vs 新事件路径 ──
	if event_ui.has_entry(entry_id):
		# === 回归路径 ===
		Logging.info("_on_event_ready_to_play: 回归路径 entry_id='%s'" % entry_id)
		BlurManager.trigger_event_blur()
		event_ui.clear_all_dim()
		event_ui.revive_entry(entry_id, all_options)
		event_ui.scroll_to_entry(entry_id)
		if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
			_start_auto_advance(data.lasting_time, all_options, entry_id)
	else:
		# === 新事件路径 ===
		Logging.info("_on_event_ready_to_play: 新事件路径 entry_id='%s' from_stack=%s" % [entry_id, from_stack])

		if not from_stack:
			event_ui.dim_previous_entries()

		if context.get("is_settlement", false):
			Logging.info("_on_event_ready_to_play: 检测到结算事件")
			BlurManager.show_picker_blur()
			_is_settlement = true
			event_ui.append_settlement_entry(data, context)
		else:
			BlurManager.trigger_event_blur()
			match data.display_speed:
				BaseEvent.DisplaySpeed.SLOW:
					event_ui.display_slow(data, all_options, context, from_stack, entry_id, EventUI.SLOW_SPEED)
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(data.lasting_time, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				BaseEvent.DisplaySpeed.SLOWEST:
					event_ui.display_slow(data, all_options, context, from_stack, entry_id, EventUI.SLOWEST_SPEED)
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(data.lasting_time, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				_:
					event_ui.append_event_entry(data, all_options, context, from_stack, entry_id)
					if data.lasting_time > 0.0 and _count_displayable_options(all_options) <= 1:
						_start_auto_advance(data.lasting_time, all_options, entry_id)

	# ── 公共尾逻辑 ──
	event_ui.register_scroll_for_input_manager()
	if data.ui_decl and data.ui_decl.audio:
		AudioManager.play_music(data.ui_decl.audio)
	else:
		AudioManager.play_sad()
	event_ui.scroll_to_bottom()


# ═══════════════════════════════════════════════════
# 选项选择处理
# ═══════════════════════════════════════════════════

func _on_event_ui_option_selected(choice_result, choice_text: String = "") -> void:
	_cancel_auto_advance()
	var entry_id := str(current_event_data.get_instance_id())

	# choice_text 为空时用 choice_result 作为标记文本
	if choice_text.is_empty():
		choice_text = str(choice_result) if choice_result else "[选择]"

	_on_event_ui_option_selected_internal(choice_result, choice_text)


## 实际处理方法 — 标记选中 + 清理结算模糊 + 转发 Director
func _on_event_ui_option_selected_internal(choice_result, choice_text: String) -> void:
	var entry_id := str(current_event_data.get_instance_id())
	event_ui.mark_chosen(entry_id, choice_text)

	if _is_settlement:
		BlurManager.hide_picker_blur()
		_is_settlement = false

	# 转发给 Director 处理所有逻辑（后果执行 + 世界恢复 + process_next）
	director.on_option_selected(choice_result, choice_text)


# ═══════════════════════════════════════════════════
# 中断按钮处理
# ═══════════════════════════════════════════════════

func _on_interrupt_available(event_key: String, context: Dictionary, btn_text: String, btn_color: Color) -> void:
	_interrupt_button.get_node("Margin/Label").text = btn_text
	_interrupt_button.tooltip_text = btn_text
	_interrupt_button.self_modulate = btn_color
	_interrupt_button.get_parent().visible = true
	Logging.info("NarrativeOverlay._on_interrupt_available: btn_text='%s' color=%s" % [btn_text, btn_color])


func _on_interrupt_unavailable() -> void:
	_interrupt_button.get_parent().visible = false
	Logging.debug("NarrativeOverlay._on_interrupt_unavailable: 中断按钮已隐藏")


func _on_interrupt_button_pressed() -> void:
	_cancel_auto_advance()
	if not current_event_data:
		Logging.warn("_on_interrupt_button_pressed: 无活跃事件，忽略重复点击")
		return
	_interrupt_button.get_parent().visible = false
	var entry_id := str(current_event_data.get_instance_id())
	event_ui.mark_chosen(entry_id, "[中断]")
	Logging.info("NarrativeOverlay._on_interrupt_button_pressed: 中断已标记，转发 Director")
	director.on_interrupt_pressed()


# ═══════════════════════════════════════════════════
# Picker 就绪处理
# ═══════════════════════════════════════════════════

func _on_picker_ready(entry: Dictionary) -> void:
	visualizer.play_show_tape()
	BlurManager.show_picker_blur()

	var data: Array = entry.get("data", [])
	var ui_constructor_raw = entry.get("ui_constructor")
	var ui_constructor: Callable = ui_constructor_raw if ui_constructor_raw != null else Callable()

	Logging.info("NarrativeOverlay._on_picker_ready: %d 个选项" % data.size())
	var attachment = event_ui.append_picker_attachment(data, ui_constructor)
	attachment.item_selected.connect(func(e):
		_on_picker_item_selected(e, entry)
	, CONNECT_ONE_SHOT)
	visualizer.dim_history_ink(attachment)


func _on_picker_item_selected(entity, entry: Dictionary) -> void:
	BlurManager.hide_picker_blur()
	visualizer.undim_history_ink()
	director.on_picker_item_selected(entity)
	Logging.info("NarrativeOverlay._on_picker_item_selected: entity=%s" % str(entity))


# ═══════════════════════════════════════════════════
# Cinematic 就绪处理
# ═══════════════════════════════════════════════════

func _on_cinematic_ready(entry: Dictionary) -> void:
	var texts: Array[String] = []
	var raw_texts = entry.get("texts", [])
	for t in raw_texts:
		if t is String:
			texts.append(t)

	Logging.info("NarrativeOverlay._on_cinematic_ready: %d 段文字" % texts.size())

	EventBus.cinematic_start.emit(texts)
	await EventBus.cinematic_finished
	await BlurManager.trigger_cinematic_post_blur(3.0)

	# 纸带追加 stub 摘要
	var summary: String = "⚡ 过场动画"
	if texts.size() > 0:
		var first := texts[0] as String
		if first.length() > 20:
			summary = "⚡ " + first.substr(0, 20) + "…"
		else:
			summary = "⚡ " + first
	event_ui.append_stub("cinematic", summary)

	director.on_cinematic_finished()
	Logging.info("NarrativeOverlay._on_cinematic_ready: Cinematic 完成")


# ═══════════════════════════════════════════════════
# FocusChat 就绪处理
# ═══════════════════════════════════════════════════

func _on_focused_chat_ready(entry: Dictionary) -> void:
	visualizer.play_show_tape()

	var data = entry.get("data")
	var context: Dictionary = entry.get("context", {})
	Logging.info("NarrativeOverlay._on_focused_chat_ready: 显示中（纸带内嵌模式）")

	# 确保父容器可见
	show()
	await get_tree().process_frame

	var chat_entry = event_ui.append_focus_chat_entry(data, context)
	chat_entry.dialogue_finished.connect(func(result):
		Logging.info("NarrativeOverlay._on_focused_chat_ready: 对话完成")
		director.on_focused_chat_finished(result)
	, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════
# 隐藏纸带
# ═══════════════════════════════════════════════════

func _on_hide_requested() -> void:
	# 🚨 如果 overlay 动画正在进行中，延迟 hide 到动画完成后执行
	if _overlay_anim_in_progress:
		Logging.info("NarrativeOverlay._on_hide_requested: overlay 动画进行中，延迟 hide")
		_deferred_hide_pending = true
		return

	BlurManager.return_to_hub()
	event_ui.clear_all_tape()
	visualizer.play_hide_tape()
	Logging.info("NarrativeOverlay._on_hide_requested: 纸带已隐藏")


# ═══════════════════════════════════════════════════
# Pop 信号处理
# ═══════════════════════════════════════════════════

func _on_pop_return_text_ready(text: String) -> void:
	event_ui.append_narrative_text(text)
	Logging.info("NarrativeOverlay._on_pop_return_text_ready: 追加过渡文本 '%s...'" % text.substr(0, min(40, text.length())))


func _on_pop_invalidate_parent(entry_id: String) -> void:
	if event_ui.has_entry(entry_id):
		event_ui.invalidate_entry(entry_id)
		Logging.info("NarrativeOverlay._on_pop_invalidate_parent: entry_id='%s' 已无效化" % entry_id)


# ═══════════════════════════════════════════════════
# main.gd 对外接口 — 委托 Visualizer
# ═══════════════════════════════════════════════════

func play_exit_animation(duration: float = 0.5) -> void:
	visualizer.play_exit_to_top(duration)


func play_enter_animation(duration: float = 0.5) -> void:
	visualizer.play_enter_from_top(duration)


# ═══════════════════════════════════════════════════════════════════
# EventBus → Overlay 动画请求
# ═══════════════════════════════════════════════════════════════════

## 监听 request_overlay_animation 信号，按策略路由到 TapeVisualizer。
## 当前支持策略:
##   - "slide_out_and_back": 纸带下滑出视口再滑回原位
func _on_overlay_animation_requested(strategy: String, params: Dictionary) -> void:
	Logging.info("NarrativeOverlay._on_overlay_animation_requested: strategy='%s', params=%s" % [strategy, params])

	match strategy:
		"slide_out_and_back":
			_overlay_anim_in_progress = true
			BlurManager.return_to_hub()
			var duration: float = params.get("duration", 0.5)
			visualizer.play_slide_out_and_back(duration)
		_:
			Logging.err("NarrativeOverlay._on_overlay_animation_requested: 未知策略 '%s'，跳过" % strategy)


## 动画完成回调 — 清除标记，处理被延迟的 hide 请求
func _on_overlay_animation_completed() -> void:
	Logging.info("NarrativeOverlay._on_overlay_animation_completed: 动画标记清除")
	_overlay_anim_in_progress = false
	if _deferred_hide_pending:
		_deferred_hide_pending = false
		Logging.info("NarrativeOverlay._on_overlay_animation_completed: 执行延迟 hide")
		_on_hide_requested()


# ═══════════════════════════════════════════════════
# 辅助方法（从原代码原样迁移）
# ═══════════════════════════════════════════════════

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
		_on_event_ui_option_selected_internal(null, "[时尽]")

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
			_on_event_ui_option_selected_internal(choice_result, choice_text)
		else:
			# 防御性：理论上不会到这里
			Logging.warn("NarrativeOverlay: auto-advance 1选项但未找到有效选项，静默关闭 entry_id='%s'" % entry_id)
			event_ui.mark_chosen(entry_id, "[时尽]")
			_on_event_ui_option_selected_internal(null, "[时尽]")
	else:
		# >1 选项：不自动选择（等待玩家手动操作）
		Logging.info("NarrativeOverlay: auto-advance 到期，%d 选项 > 1，不自动选择 entry_id='%s'" % [displayable_count, entry_id])


# ── UIDecl 背景纹理动态替换 ──────────────────────

## 根据事件的 ui_decl.background_narrative 动态替换 TapeContainer 纸带的
## StyleBoxTexture 背景纹理。有自定义纹理就用自定义；没有则回退到默认宣纸纹理。
## 契约：总是设置纹理，绝不跳过 — 防止上一事件的定制纹理残留。
func _apply_ui_decl_background(data: BaseEvent) -> void:
	# 委托给 StyleManager 处理背景切换
	var target_texture: Texture2D = null
	if data.ui_decl and data.ui_decl.background_narrative:
		target_texture = data.ui_decl.background_narrative
	StyleManager.apply_event_background(tape_container, target_texture)


# ── 背景纹理交换检测 ────────────────────────────

## 判断是否需要「抽纸动画」：纸带上有历史条目 且 目标纹理 ≠ 当前纹理。
## 目标纹理 = 事件声明的 background_narrative，若无声明则回退 _default_background_texture。
## @return: true → 需要抽上去清空条目再抽下来；false → 正常流程
func _needs_background_swap(data: BaseEvent) -> bool:
	# 条件 1：纸带上必须有历史条目
	var history_child_count: int = event_ui._tape_content.get_child_count()
	if history_child_count <= 0:
		Logging.info("_needs_background_swap: 纸带无历史条目，无需交换背景")
		return false

	# 条件 2：取出当前纹理与目标纹理（委托 StyleManager 查询）
	var current_texture: Texture2D = StyleManager.get_container_background(tape_container)
	# 目标纹理：事件声明了自定义背景就用自定义，否则回退默认宣纸
	var new_texture: Texture2D
	if data.ui_decl and data.ui_decl.background_narrative:
		new_texture = data.ui_decl.background_narrative
	else:
		new_texture = StyleManager.get_default_background(tape_container)

	# 条件 3：纹理确实不同
	if current_texture == new_texture:
		Logging.info("_needs_background_swap: 背景纹理未变化（%s），无需交换" % current_texture.resource_path if current_texture else "(null)")
		return false

	Logging.info("_needs_background_swap: 检测到背景变化 '%s' → '%s'，触发抽纸动画" % [
		current_texture.resource_path if current_texture else "(null)",
		new_texture.resource_path if new_texture else "(null)"
	])
	return true

# ── StyleManager: frost 策略绑定 ───────────────────────────

## 向 StyleManager 注册 tape_container 并绑定 frost 策略
## health=100 时 progress=0.0（无冻结），health=0 时 progress=1.0（彻底冻结）
func _bind_frost_strategy() -> void:
	var data := StyleData.new()
	data.strategy_name = "frost"
	data.target_property = "health"
	data.start_property_value = 100.0
	data.target_property_value = 0.0
	data.shader_resource = preload("res://shaders/frost.gdshader")
	data.shader_parameter_names = ["freeze_progress"]
	data.container = tape_container
	# stylebox_texture null → 不修改纸纹理
	StyleManager.bind(data)

	# 首次 bind 后，初始为 default 策略（无 shader），
	# 若希望默认激活 frost 可直接 switch：
	StyleManager.switch_strategy(tape_container, "frost")

	Logging.info("NarrativeOverlay: frost 策略已绑定 → tape_container")
