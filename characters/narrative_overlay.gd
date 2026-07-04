class_name NarrativeOverlay extends PanelContainer

## 事件显示开始时发射（供 HoverPopupManager 等外部系统监听）
signal event_display_started()
## 事件显示结束（纸带隐藏）时发射
signal event_display_ended()

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
@onready var event_ui = $TapeContainer/VBox/EventHistory
@onready var _interrupt_button: Button = $InterruptButton/Button
@onready var tape_container: PanelContainer = $TapeContainer
@onready var hover_container: PanelContainer = $TapeContainer/VBox/HoverContainer
@onready var hover_label: RichTextLabel = $TapeContainer/VBox/HoverContainer/SmoothScrollContainer/V/HoverLabel
@onready var hover_separator: HSeparator = $TapeContainer/VBox/HoverContainer/SmoothScrollContainer/V/HSeparator
@onready var hover_title: Label = $TapeContainer/VBox/HoverContainer/SmoothScrollContainer/V/Label
@onready var time_left_rect: TextureRect = $TapeContainer/VBox/HoverContainer/TimeLeft
@onready var time_label: Label = $TapeContainer/VBox/HoverContainer/TimeLeft/TimeLabel

# ── Overlay 本地状态（仅 UI 相关）────────────────────
var current_event_data: BaseEvent
var _auto_advance_timer: Timer = null
var _is_settlement: bool = false
var _default_background_texture: Texture2D  # tscn 中 tape_container 的初始宣纸纹理
var _overlay_anim_in_progress: bool = false  # overlay 动画进行中，阻止 tape_needs_hide
var _deferred_hide_pending: bool = false     # 动画期间收到 hide 请求，动画完成后执行
var _auto_advance_blocked: bool = false      # 非事件状态下阻止 _start_auto_advance（cinematic/picker/focuschat 等）
var _is_hover_displaying: bool = false       # 🆕 当前是否正在显示 hover 内容
var _daily_refresh_pending: bool = false     # 🆕 hover 期间收到刷新请求，hover 结束后执行
var _daily_refresh_queued: bool = false      # 🆕 call_deferred 防抖令牌
# ── 日常面板快照（与 hover 快照独立）──
var _daily_snapshot_text: String = ""
var _daily_snapshot_sep: bool = false
var _daily_snapshot_title: String = "独白"
# ── hover 快照（用于 show/hide_hover_text）──
var _hover_snapshot_text: String = ""
var _hover_snapshot_sep: bool = false
var _hover_snapshot_title: String = ""
# ── hover 倒计时（TimeLeft 动画）──
var _time_left_original_modulate: Color
var _hover_countdown_timer: Timer = null
var _hover_countdown_tween: Tween = null

# ═══════════════════════════════════════════════════
# _ready() — 信号接线
# ═══════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# ── HoverContainer 永久可见占位 + mouse 事件接收 + 初次刷新日常面板 ──
	hover_container.visible = true
	hover_container.mouse_filter = Control.MOUSE_FILTER_STOP
	# 存 TimeLeft 原始 modulate 快照
	_time_left_original_modulate = time_left_rect.self_modulate
	time_left_rect.visible = false
	# 子控件全部 IGNORE，防止吃掉 mouse 事件
	_set_hover_children_mouse_ignore(hover_container)
	# 🆕 hover_container 的鼠标事件代理到 HoverPopupManager（延长 hover 时间）
	hover_container.mouse_entered.connect(_on_hover_container_mouse_entered)
	hover_container.mouse_exited.connect(_on_hover_container_mouse_exited)
	refresh_daily_panel()

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

	# ── Overlay → Director ──
	# event_ui.option_selected → 先做 UI 清理再转发
	event_ui.option_selected.connect(_on_event_ui_option_selected)
	# 中断按钮 → 先做 UI 标记再转发
	_interrupt_button.pressed.connect(_on_interrupt_button_pressed)

	# ── EventBus → Overlay 动画请求 ──
	EventBus.request_overlay_animation.connect(_on_overlay_animation_requested)
	# ── TapeVisualizer → 动画完成回调 ──
	visualizer.overlay_animation_finished.connect(_on_overlay_animation_completed)

	# 🆕 日常面板刷新：属性/特质/flag 变动时更新
	if not EventBus.on_trait_change.is_connected(_on_daily_refresh_signal):
		EventBus.on_trait_change.connect(_on_daily_refresh_signal)
	if not EventBus.imaginary_changed.is_connected(_on_daily_refresh_signal):
		EventBus.imaginary_changed.connect(_on_daily_refresh_signal)
	if not EventBus.on_flag_change.is_connected(_on_daily_refresh_signal):
		EventBus.on_flag_change.connect(_on_daily_refresh_signal)

	Logging.info("NarrativeOverlay._ready: 信号接线完成")


# ═══════════════════════════════════════════════════
# 核心：事件入场装配
# ═══════════════════════════════════════════════════

func _on_event_ready_to_play(entry: Dictionary, from_stack: bool) -> void:
	# ── 进入事件状态，解除 auto-advance 封锁，dismiss 所有 hover ──
	_auto_advance_blocked = false
	HoverPopupManager.dismiss_all()

	# 🆕 事件开始时：恢复 overlay 快照位置 + 显示 tape（HoverContainer 保持 daily 内容）
	visualizer.restore_snapshot()
	show()

	# 🆕 通知 HoverPopupManager：事件活跃中，hover 无需动画直接显示
	HoverPopupManager.set_event_active(true)

	# 🆕 发射事件显示开始信号
	event_display_started.emit()

	var data: BaseEvent = entry.get("data")
	var context: Dictionary = entry.get("context", {})

	# ── 事件入场装配（从原 apply_narrative 迁出）──
	var all_options: Array = data.init(context)

	# 防御性检查：0 选项 + lasting_time=0 → 跳过
	if _has_no_displayable_option(all_options):
		var _lt0: float = data.ui_decl.lasting_time if data.ui_decl else 0.0
		if _lt0 <= 0.0:
			Logging.err("_on_event_ready_to_play: 事件 '%s' 所有选项文本为空且 lasting_time=0，跳过" % data.name)
			director.on_option_selected(null, "[跳过]")
			return
		Logging.info("_on_event_ready_to_play: 事件 '%s' 0 选项但 lasting_time=%.1f > 0" % [data.name, _lt0])

	EventBus.event_shown.emit(data)
	if data.ui_decl and data.ui_decl.epitaph_text:
		TimeService.register_to_master_timeline(data.time, data.name, data.ui_decl.epitaph_text)

	current_event_data = data
	var entry_id := str(data.get_instance_id())

	# 🆕 从 entry 中读取 is_pop_regression 标记（由 NarrativeDirector._on_pop_event 写入）
	# 区分 "pop 回归父事件" 与 "循环重入的旧事件"（Bug 2 修复）
	var is_pop_regression: bool = entry.get("is_pop_regression", false)
	Logging.info("_on_event_ready_to_play: event='%s' from_stack=%s is_pop_regression=%s" % [data.name, from_stack, is_pop_regression])

	# ── 背景交换判断（Overlay 决策，不是 Director）──
	if _needs_background_swap(data):
		# 通过回调注入清空条目 + 应用新纹理
		# 与 _needs_background_swap 保持一致的 fallback 逻辑
		var _swap_target_texture: Texture2D = data.ui_decl.background_narrative if (data.ui_decl and data.ui_decl.background_narrative) else StyleManager.get_default_background(tape_container)
		await visualizer.play_swap_background(
			_swap_target_texture,
			func():
				event_ui.clear_all_tape()
				_apply_ui_decl_background(data)
		)
		# ⭐ 背景交换完成后统一渲染事件内容 + 设置 auto-advance
		_render_event_content(data, all_options, context, from_stack, entry_id, is_pop_regression)
	else:
		# ── 动画策略路由 ──
		if data.ui_decl and data.ui_decl.animation_strategy == ENUMS.ANIMATION_STRATEGY.SLIDE_FROM_BOTTOM:
			visualizer.play_show_tape_from_bottom()
		else:
			visualizer.play_show_tape()
		_apply_ui_decl_background(data)

		# ⭐ 统一的事件内容渲染 + auto-advance 设置
		_render_event_content(data, all_options, context, from_stack, entry_id, is_pop_regression)

		# ── 公共尾逻辑 ──
	event_ui.register_scroll_for_input_manager()
	if data.ui_decl and data.ui_decl.audio:
		AudioManager.play_music(data.ui_decl.audio)
	event_ui.scroll_to_bottom()


# ═══════════════════════════════════════════════════
# 事件内容渲染 + auto-advance（提取自 _on_event_ready_to_play）
# ═══════════════════════════════════════════════════

## 渲染事件内容并设置 auto-advance Timer
## 在 _on_event_ready_to_play 的 if/else 两个分支中统一调用，
## 确保 background_swap 路径和正常路径都不遗漏。
## @param is_pop_regression: 来自 Director 的 pop 回归标记，替代不精确的 has_entry() 判断
func _render_event_content(data: BaseEvent, all_options: Array, context: Dictionary, from_stack: bool, entry_id: String, is_pop_regression: bool = false) -> void:
	# ── 分支：pop 回归路径 vs 新事件路径 ──
	# pop 回归的父事件在纸带上已存在旧条目（含 "即决" 烙印），
	# 底部追加仅选项的新条目，不重复渲染 title/content/example
	# 🆕 is_pop_regression + has_entry 双重判断：
	#    - 单独 has_entry() 无法区分 "pop 回归" 与 "循环重入"（Bug 2 根源）
	#    - 单独 is_pop_regression 在 pop_to_event 未处理事件的边缘情况下可能误判
	#    - 两者同时满足才走 pop 回归路径
	var _lt: float = data.ui_decl.lasting_time if data.ui_decl else 0.0
	var _ds: int = data.ui_decl.display_speed if data.ui_decl else 0
	if is_pop_regression and event_ui.has_entry(entry_id):
		# === pop 回归路径：底部追加纯选项条目 ===
		Logging.info("_render_event_content: pop回归路径 entry_id='%s'" % entry_id)
		BlurManager.trigger_event_blur()
		event_ui.clear_all_dim()
		event_ui.append_pop_regression_entry(data, all_options, entry_id)
		event_ui.scroll_to_bottom()
		if _lt > 0.0 and _count_displayable_options(all_options) <= 1:
			_start_auto_advance(_lt, all_options, entry_id)
	else:
		# === 新事件路径 ===
		Logging.info("_render_event_content: 新事件路径 entry_id='%s' from_stack=%s" % [entry_id, from_stack])

		if not from_stack:
			event_ui.dim_previous_entries()

		if context.get("is_settlement", false):
			Logging.info("_render_event_content: 检测到结算事件")
			BlurManager.show_picker_blur()
			_is_settlement = true
			event_ui.append_settlement_entry(data, context)
		else:
			BlurManager.trigger_event_blur()
			match _ds:
				UIDecl.DisplaySpeed.SLOW:
					event_ui.display_slow(data, all_options, context, from_stack, entry_id, EventUI.SLOW_SPEED)
					if _lt > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(_lt, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				UIDecl.DisplaySpeed.SLOWEST:
					event_ui.display_slow(data, all_options, context, from_stack, entry_id, EventUI.SLOWEST_SPEED)
					if _lt > 0.0 and _count_displayable_options(all_options) <= 1:
						event_ui.display_complete.connect(func():
							_start_auto_advance(_lt, all_options, entry_id)
						, CONNECT_ONE_SHOT)
				_:
					event_ui.append_event_entry(data, all_options, context, from_stack, entry_id)
					if _lt > 0.0 and _count_displayable_options(all_options) <= 1:
						_start_auto_advance(_lt, all_options, entry_id)


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
	# 🚨 进入 Picker 状态：取消任何残留的 auto-advance Timer，阻止 display_complete 二次启动
	_cancel_auto_advance()
	_auto_advance_blocked = true

	# 🆕 Picker 也视为事件活跃，锁定右侧行动栏
	HoverPopupManager.set_event_active(true)
	event_display_started.emit()

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
	# 🆕 Picker 选择完成，解锁行动栏
	HoverPopupManager.set_event_active(false)
	event_display_ended.emit()
	director.on_picker_item_selected(entity)
	Logging.info("NarrativeOverlay._on_picker_item_selected: entity=%s" % str(entity))


# ═══════════════════════════════════════════════════
# Cinematic 就绪处理
# ═══════════════════════════════════════════════════

func _on_cinematic_ready(entry: Dictionary) -> void:
	# 🚨 进入 Cinematic 状态：取消任何残留的 auto-advance Timer，阻止 display_complete 二次启动
	_cancel_auto_advance()
	_auto_advance_blocked = true

	# 🆕 Cinematic 也视为事件活跃，锁定右侧行动栏
	HoverPopupManager.set_event_active(true)
	event_display_started.emit()

	var texts: Array[String] = []
	var raw_texts = entry.get("texts", [])
	for t in raw_texts:
		if t is String:
			texts.append(t)

	Logging.info("NarrativeOverlay._on_cinematic_ready: %d 段文字" % texts.size())

	var config: Dictionary = entry.get("config", {})
	EventBus.cinematic_start.emit(texts, config)
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

	# 🆕 Cinematic 完成，解锁行动栏
	HoverPopupManager.set_event_active(false)
	event_display_ended.emit()

	director.on_cinematic_finished()
	Logging.info("NarrativeOverlay._on_cinematic_ready: Cinematic 完成")


# ═══════════════════════════════════════════════════
# FocusChat 就绪处理
# ═══════════════════════════════════════════════════

func _on_focused_chat_ready(entry: Dictionary) -> void:
	# 🚨 进入 FocusChat 状态：取消任何残留的 auto-advance Timer，阻止 display_complete 二次启动
	_cancel_auto_advance()
	_auto_advance_blocked = true

	# 🆕 FocusChat 也视为事件活跃，锁定右侧行动栏
	HoverPopupManager.set_event_active(true)
	event_display_started.emit()

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
		# 🆕 FocusChat 完成，解锁行动栏
		HoverPopupManager.set_event_active(false)
		event_display_ended.emit()
		director.on_focused_chat_finished(result)
	, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════
# 隐藏纸带
# ═══════════════════════════════════════════════════

func _on_hide_requested() -> void:
	# 🚨 隐藏纸带时取消 auto-advance（防止在 hide 动画期间触发）
	_cancel_auto_advance()
	_auto_advance_blocked = true
	# 🆕 隐藏纸带时同时清除 hover 文本
	hide_hover_text()

	# 🆕 通知 HoverPopupManager：事件结束，恢复动画模式
	HoverPopupManager.set_event_active(false)
	event_display_ended.emit()

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
	# 🚨 非事件状态下禁止启动 auto-advance（cinematic/picker/focuschat 活跃期间）
	if _auto_advance_blocked:
		Logging.info("_start_auto_advance: auto-advance 被封锁（_auto_advance_blocked=true），跳过 entry_id='%s'" % entry_id)
		return
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
const FROST_MATERIAL := preload("res://shaders/frost_shader_material.tres")

func _bind_frost_strategy() -> void:
	var data := StyleData.new()
	data.strategy_name = "frost"
	data.target_property = "health"
	data.start_property_value = 100.0
	data.target_property_value = 0.0
	data.shader_material = FROST_MATERIAL
	data.shader_parameter_names = ["freeze_progress"]
	data.container = tape_container
	data.stylebox = preload("res://shaders/frostland_stylebox.tres")
	data.narrative_text_theme = "FrozenNarrativeText"
	data.title_text_theme = "FrozenTitleText"
	data.inner_thought_theme = "FrozenInnerThoughtText"
	data.default_text_theme = "FrozenDefaultText"
	StyleManager.bind(data)
	# frost 仅在事件触发时由 StyleStrategyOperator 激活，默认不挂载 shader
	Logging.info("NarrativeOverlay: frost 策略已注册 → tape_container (等待事件激活)")

# ── HoverDisplayFlow 对外接口 ──────────────────────────

## 显示 hover 文本到 HoverContainer。
## SLIDE_FROM_RIGHT / BELOW_OVERLAY 两个 Delegate 均通过此接口设置内容。
## 操作：存当前日常面板快照 → 设 hover 内容 → 标记 _is_hover_displaying。
func show_hover_text(narrative: String, vector: String) -> void:
	# 🔒 只在首次进入 hover 时存快照（避免连续 hover 污染 daily 快照）
	if not _is_hover_displaying:
		_store_hover_snapshot()
	_is_hover_displaying = true
	hover_title.text = "效果"
	var text_parts: Array[String] = []
	if not narrative.is_empty():
		text_parts.append(narrative)
	if not vector.is_empty():
		if not text_parts.is_empty():
			text_parts.append("")  # 空行分隔
		text_parts.append(vector)
	hover_label.text = "\n".join(text_parts)
	hover_separator.visible = not vector.is_empty()

	Logging.info("NarrativeOverlay.show_hover_text: narrative=%d chars, vector=%d chars" % [narrative.length(), vector.length()])

## 隐藏 hover 内容：恢复日常面板快照 + 检查延迟刷新
func hide_hover_text() -> void:
	_cancel_hover_countdown()
	_restore_hover_snapshot()
	_is_hover_displaying = false
	# 🆕 hover 期间有等待的刷新请求，现在执行
	if _daily_refresh_pending:
		_daily_refresh_pending = false
		Logging.info("NarrativeOverlay.hide_hover_text: executing pending daily refresh")
		refresh_daily_panel()
	Logging.info("NarrativeOverlay.hide_hover_text: snapshot restored, is_hover_displaying=false")

## 保存当前 hover label/separator/title 为快照（用于 hover 覆盖前）
func _store_hover_snapshot() -> void:
	_hover_snapshot_text = hover_label.text
	_hover_snapshot_sep = hover_separator.visible
	_hover_snapshot_title = hover_title.text
	Logging.info("NarrativeOverlay._store_hover_snapshot: title='%s' text='%s' sep=%s" % [_hover_snapshot_title, _hover_snapshot_text, str(_hover_snapshot_sep)])

## 恢复 hover label/separator/title 到快照状态
func _restore_hover_snapshot() -> void:
	hover_label.text = _hover_snapshot_text
	hover_separator.visible = _hover_snapshot_sep
	hover_title.text = _hover_snapshot_title
	Logging.info("NarrativeOverlay._restore_hover_snapshot: title='%s' text='%s' sep=%s" % [_hover_snapshot_title, _hover_snapshot_text, str(_hover_snapshot_sep)])

# ═══════════════════════════════════════════════════
# 🆕 日常效果面板（与 HoverDisplayFlow 共享 HoverContainer UI）
# ═══════════════════════════════════════════════════

## 刷新日常面板内容：收集 survival goal + 潜意识碎碎念 → 写入 HoverContainer
func refresh_daily_panel() -> void:
	# 如果正在 hover 显示中，延迟到 hover 结束后刷新
	if _is_hover_displaying:
		Logging.info("NarrativeOverlay.refresh_daily_panel: hover displaying, deferring")
		_daily_refresh_pending = true
		return
	var parts: Array[String] = []
	var goal_text := _check_survival_goal()
	if not goal_text.is_empty():
		parts.append(goal_text)
	var murmur_text := _subconscious_murmur()
	if not murmur_text.is_empty():
		parts.append(murmur_text)
	var combined: String
	if parts.is_empty():
		combined = _random_fallback_murmur()
	else:
		combined = "\n\n".join(parts)
	# 写日常面板快照（供 hover 结束后恢复）
	_daily_snapshot_text = combined
	_daily_snapshot_sep = true
	_daily_snapshot_title = "独白"
	# 应用到 UI
	hover_title.text = "独白"
	hover_separator.visible = true
	hover_label.text = combined
	Logging.info("NarrativeOverlay.refresh_daily_panel: combined=%d chars" % combined.length())

## 1. 检查宏观目标 + 倒计时：钱是否够每旬 cost
## 不足时返回杜甫口吻的一句话，否则返回 ""
func _check_survival_goal() -> String:
	var current_money := PlayerState.get_stat_val(ENUMS.PROPS.MONEY) as int
	if current_money >= 0:
		return ""
	var needed = abs(current_money)
	if current_money > -5:
		return "囊中已近空空，再过一旬怕是揭不开锅了…"
	elif current_money <= -30:
		return "债台高筑，负债%d钱…这日子何时是个头？" % needed
	else:
		return "手头缺了%d钱，下一旬的生计还没着落。" % needed

## 2. 潜意识碎碎念：检查中毒 / 崴脚
## 有 debuff 时返回杜甫口吻的一句话，否则返回 ""
func _subconscious_murmur() -> String:
	if PlayerState.has_trait("poisoned"):
		return "腹中隐隐作痛，这毒物怕不是那日试药留下的…"
	if PlayerState.has_trait("sprained_ankle"):
		return "脚踝还在隐隐发疼，走路得慢些。"
	return ""

## 两个函数均无内容时的 fallback：硬编码 5 句杜甫独白，随机挑一句
const FALLBACK_MURMURS: Array[String] = [
	"人生如寄，山河万里，何处是归程？",
	"致君尧舜上，再使风俗淳。",
	"安得广厦千万间，大庇天下寒士俱欢颜。",
	"白日放歌须纵酒，青春作伴好还乡。",
	"朱门酒肉臭，路有冻死骨。",
]

func _random_fallback_murmur() -> String:
	var idx: int = randi() % FALLBACK_MURMURS.size()
	return FALLBACK_MURMURS[idx]

## 🆕 信号回调：属性/特质/flag 变动时请求刷新日常面板
## 使用 call_deferred + guard 防止同帧内信号爆发导致 stack overflow
func _on_daily_refresh_signal() -> void:
	if _daily_refresh_queued:
		return
	_daily_refresh_queued = true
	call_deferred("_deferred_daily_refresh")

func _deferred_daily_refresh() -> void:
	_daily_refresh_queued = false
	Logging.info("NarrativeOverlay._deferred_daily_refresh: executing")
	refresh_daily_panel()

# 🆕 代理 hover_container 的鼠标事件到 HoverPopupManager
# 鼠标进入 hover_container = 等同于还悬浮在原按钮上
func _on_hover_container_mouse_entered() -> void:
	Logging.info("NarrativeOverlay._on_hover_container_mouse_entered: proxy to HoverPopupManager")
	HoverPopupManager._on_proxy_enter()

# 鼠标离开 hover_container = 等同于离开原按钮
func _on_hover_container_mouse_exited() -> void:
	Logging.info("NarrativeOverlay._on_hover_container_mouse_exited: proxy to HoverPopupManager")
	HoverPopupManager._on_proxy_exit()

# 🆕 递归设置所有子控件 mouse_filter = IGNORE（不包含自身）
# 保留 SmoothScrollContainer 的 scroll/drag 能力（PASS）
func _set_hover_children_mouse_ignore(node: Control) -> void:
	for child in node.get_children():
		if child == node:
			continue
		if not child is Control:
			continue
		# SmoothScrollContainer 需要 PASS 来接收滚动/拖拽事件，其子控件仍设为 IGNORE
		if child is SmoothScrollContainer:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			# 递归设置 SmoothScrollContainer 的子控件
			for grandchild in (child as Control).get_children():
				if grandchild is Control:
					grandchild.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 继续递归（对所有 Control 子节点）
		_set_hover_children_mouse_ignore(child)

# ═══════════════════════════════════════════════════
# 🆕 Hover 倒计时 UI（TimeLeft + TimeLabel）
# ═══════════════════════════════════════════════════

const HOVER_GRACE: float = 0.75
const COUNTDOWN_INTERVAL: float = 0.25
const COUNTDOWN_TARGET_COLOR: Color = Color("#CDB89B")

## 启动倒计时：TimeLeft visible + Tween modulate + Timer 更新 label
func _start_hover_countdown() -> void:
	_cancel_hover_countdown()
	# 重置 TimeLeft 到快照颜色
	time_left_rect.self_modulate = _time_left_original_modulate
	time_left_rect.visible = true
	time_label.text = "%.2f" % HOVER_GRACE
	# Tween：从快照颜色 → COUNTDOWN_TARGET_COLOR
	if _hover_countdown_tween:
		_hover_countdown_tween.kill()
	_hover_countdown_tween = create_tween()
	_hover_countdown_tween.tween_property(time_left_rect, "self_modulate", COUNTDOWN_TARGET_COLOR, HOVER_GRACE)
	# Timer：每 0.25s 更新 label
	_hover_countdown_timer = Timer.new()
	_hover_countdown_timer.wait_time = COUNTDOWN_INTERVAL
	_hover_countdown_timer.one_shot = false
	_hover_countdown_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hover_countdown_timer)
	_hover_countdown_timer.timeout.connect(_on_countdown_tick)
	_hover_countdown_timer.start()
	Logging.info("NarrativeOverlay._start_hover_countdown: grace=%.2fs" % HOVER_GRACE)

func _on_countdown_tick() -> void:
	if not _hover_countdown_timer:
		return
	# Timer.wait_time=0.25, time_left 递减 → 累积 elapsed
	var elapsed: float = HOVER_GRACE - _hover_countdown_timer.time_left
	if elapsed < 0.0:
		elapsed = 0.0
	var remaining: float = max(HOVER_GRACE - elapsed, 0.0)
	time_label.text = "%.2f" % remaining
	if remaining <= 0.01:
		_cancel_hover_countdown()

## 取消倒计时：隐藏 TimeLeft + 停止 Timer + 杀 Tween
func _cancel_hover_countdown() -> void:
	time_left_rect.visible = false
	if _hover_countdown_timer:
		_hover_countdown_timer.queue_free()
		_hover_countdown_timer = null
	if _hover_countdown_tween:
		_hover_countdown_tween.kill()
		_hover_countdown_tween = null
	Logging.info("NarrativeOverlay._cancel_hover_countdown: cancelled")
