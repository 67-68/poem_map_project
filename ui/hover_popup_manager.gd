extends Node
const _HoverInfoPopup = preload("res://ui/hover_info_popup.gd")

## P社式 Hover 延迟弹出管理器（Autoload）v3.0
##
## 用法:
##   HoverPopupManager.register(my_button, popup, 0.2, 0.15, FlowType.POPUP_LEGACY)
##   HoverPopupManager.register(my_button, {"narrative":"...","vector":"..."}, 0.2, 1.0, FlowType.SLIDE_FROM_RIGHT)
##
## 状态机（HoverBinding 自治）:
##   IDLE → DELAYING → SHOWING → HIDE_PENDING → IDLE
##
## 三种显示流 (FlowType):
##   POPUP_LEGACY     — 原有浮动 popup（ambition_hud 等）
##   SLIDE_FROM_RIGHT — NarrativeOverlay 从右侧滑入（action 按钮 hover）; 事件活跃时降级为直接显示（同 BELOW_OVERLAY）
##   BELOW_OVERLAY    — hover_container 淡入在纸带下方（picker/event 选项 hover）
##
## 事件锁:
##   set_event_active(true)  → SLIDE_FROM_RIGHT 降级为直接显示（无滑动动画）
##   set_event_active(false) → 恢复滑动动画

# ── 显示流枚举 ─────────────────────────────────────────

enum FlowType { POPUP_LEGACY, SLIDE_FROM_RIGHT, BELOW_OVERLAY }

# ── 显示委托抽象基类 ───────────────────────────────────

## 🆕 事件活跃标志 — 由 NarrativeOverlay 设置
static var _is_event_active: bool = false

## 设置事件活跃状态（由 NarrativeOverlay 调用）
## true  → SLIDE_FROM_RIGHT 降级为直接显示（无动画），hover 文本加前缀"请先完成当前事件"
## false → 恢复滑动动画，移除前缀
static func set_event_active(active: bool) -> void:
	_is_event_active = active
	Logging.info("HoverPopupManager.set_event_active: %s" % str(active))

class HoverDisplayDelegate:
	## 进入 SHOWING 状态时调用
	func on_enter(_binding) -> void:
		pass
	## 退出 SHOWING 状态时调用
	func on_exit(_binding) -> void:
		pass

## 从右侧滑入 NarrativeOverlay，显示 hover 文本。
## 🔒 动画锁：slide-in 期间阻止 mouse_exit 触发 slide-out，等动画播完再处理排队的 exit。
##    slide-out 同理：播放期间阻止 slide-in 重入，等动画播完。
## 🆕 事件活跃时降级为直接显示（同 BELOW_OVERLAY），无滑动动画。
class SlideFromRightDelegate extends HoverDisplayDelegate:
	var _manager_ref: WeakRef
	var _animating: bool = false          # 动画进行中，阻止重入
	var _pending_exit: bool = false       # 动画期间收到 exit 请求，排队等动画完成后执行
	var _pending_exit_binding = null      # 排队时的 binding 引用

	func _init(manager: Node) -> void:
		_manager_ref = weakref(manager)

	func on_enter(binding) -> void:
		# 🔒 动画锁：slide-out 动画进行中，忽略 enter（等它播完）
		if _animating:
			Logging.info("HoverPopupManager.SlideFromRightDelegate: on_enter ignored, animating (pending_exit=%s)" % str(_pending_exit))
			# 取消排队 exit — 用户回来了
			_pending_exit = false
			_pending_exit_binding = null
			return

		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if not overlay:
			Logging.err("HoverPopupManager.SlideFromRightDelegate: NarrativeOverlay not found")
			return
		var text_data: Dictionary = binding.delegate_data if binding.delegate_data is Dictionary else {}
		var narrative: String = text_data.get("narrative", "")
		var vector: String = text_data.get("vector", "")

		# 🆕 事件活跃时：前缀"请先完成当前事件再选择"，直接显示（不滑动）
		if HoverPopupManager._is_event_active:
			narrative = "[color=#cc6666]⚠ 请先完成当前事件再选择[/color]\n\n" + narrative
			overlay.show_hover_text(narrative, vector)
			Logging.info("HoverPopupManager.SlideFromRightDelegate: event active → direct display (no animation)")
			return

		overlay.show_hover_text(narrative, vector)
		var visualizer = overlay.get_node_or_null("TapeVisualizer")
		if visualizer and visualizer.has_method("play_slide_in_from_right"):
			_animating = true
			visualizer.play_slide_in_from_right(0.1)
			Logging.info("HoverPopupManager.SlideFromRightDelegate: slide_in_from_right started, animating=true")
			# 等待动画完成后清除锁
			await _wait_for_anim(visualizer)
			_animating = false
			Logging.info("HoverPopupManager.SlideFromRightDelegate: slide_in finished, animating=false, pending_exit=%s" % str(_pending_exit))
			# 动画完成后，如果有排队的 exit，执行它
			if _pending_exit:
				_pending_exit = false
				_exec_slide_out(overlay)
		else:
			Logging.err("HoverPopupManager.SlideFromRightDelegate: TapeVisualizer not found or missing method")

	func on_exit(_binding) -> void:
		# 🔒 动画锁：slide-in 动画进行中，排队 exit
		if _animating:
			Logging.info("HoverPopupManager.SlideFromRightDelegate: on_exit queued, animating")
			_pending_exit = true
			return
		# 🆕 事件活跃时：直接隐藏，无 slide-out 动画
		if HoverPopupManager._is_event_active:
			var mgr = _manager_ref.get_ref()
			if mgr:
				var overlay = mgr._get_narrative_overlay()
				if overlay and overlay.has_method("hide_hover_text"):
					overlay.hide_hover_text()
			Logging.info("HoverPopupManager.SlideFromRightDelegate: event active exit → direct hide")
			return
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if not overlay:
			return
		_exec_slide_out(overlay)

	## 实际执行 slide-out 动画
	func _exec_slide_out(overlay: Node) -> void:
		var visualizer = overlay.get_node_or_null("TapeVisualizer")
		if visualizer and visualizer.has_method("play_slide_to_right"):
			_animating = true
			visualizer.play_slide_to_right(0.1)
			Logging.info("HoverPopupManager.SlideFromRightDelegate: slide_to_right started, animating=true")
			await _wait_for_anim(visualizer)
			_animating = false
			# 🆕 动画完成后：隐藏 hover 文本容器
			if overlay.has_method("hide_hover_text"):
				overlay.hide_hover_text()
			Logging.info("HoverPopupManager.SlideFromRightDelegate: slide_out finished, animating=false, hover hidden")
		else:
			Logging.err("HoverPopupManager.SlideFromRightDelegate: TapeVisualizer not found for slide_out")

	## 等待 tape_visualizer 的 _tween 完成（轮询，简单可靠）
	func _wait_for_anim(visualizer: Node) -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if not tree:
			return
		# 最坏等 5 秒防止永久卡死
		for _i in range(100):
			await tree.process_frame
			if not visualizer._tween or not visualizer._tween.is_valid() or not visualizer._tween.is_running():
				break

## 在 NarrativeOverlay 底部淡入 hover 文本
class BelowOverlayDelegate extends HoverDisplayDelegate:
	var _manager_ref: WeakRef

	func _init(manager: Node) -> void:
		_manager_ref = weakref(manager)

	func on_enter(binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if not overlay:
			Logging.err("HoverPopupManager.BelowOverlayDelegate: NarrativeOverlay not found")
			return
		var text_data: Dictionary = binding.delegate_data if binding.delegate_data is Dictionary else {}
		var narrative: String = text_data.get("narrative", "")
		var vector: String = text_data.get("vector", "")
		overlay.show_hover_text(narrative, vector)
		Logging.info("HoverPopupManager.BelowOverlayDelegate: hover text shown below overlay")

	func on_exit(_binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if overlay and overlay.has_method("hide_hover_text"):
			overlay.hide_hover_text()
			Logging.info("HoverPopupManager.BelowOverlayDelegate: hover text hidden")

## 原有浮动 popup（行为不变）
class PopupLegacyDelegate extends HoverDisplayDelegate:
	var _manager_ref: WeakRef

	func _init(manager: Node) -> void:
		_manager_ref = weakref(manager)

	func on_enter(binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		if not is_instance_valid(binding.popup):
			Logging.err("HoverPopupManager.PopupLegacyDelegate: popup freed for trigger=%s, forcing IDLE" % binding.trigger.name)
			binding.transition_to(HoverBinding.State.IDLE)
			return
		mgr._position_popup_at_mouse(binding)
		binding.popup.z_index = 100
		binding.popup.visible = true
		Logging.info("HoverPopupManager.PopupLegacyDelegate: showing popup=%s at position %s" % [binding.popup.name, binding.popup.position])

	func on_exit(binding) -> void:
		if is_instance_valid(binding.popup):
			binding.popup.visible = false
			Logging.info("HoverPopupManager.PopupLegacyDelegate: hiding popup=%s" % binding.popup.name)

# ── 内部数据结构：自治状态机 ─────────────────────────────

class HoverBinding:
	enum State { IDLE, DELAYING, SHOWING, HIDE_PENDING }

	var trigger: Control
	var popup: Control = null          # 仅 POPUP_LEGACY 使用
	var delay: float = 0.2
	var hide_grace: float = 0.15
	var flow_type: FlowType = FlowType.POPUP_LEGACY
	var delegate: HoverDisplayDelegate
	var delegate_data: Variant          # Dictionary{narrative,vector} 或 null
	var show_timer: Timer
	var hide_timer: Timer
	var trigger_hovered: bool = false
	var popup_hovered: bool = false
	var state: State = State.IDLE

	# 已绑定的 Callable（用于 disconnect 时精确匹配）
	var _bound_trigger_enter: Callable
	var _bound_trigger_exit: Callable
	var _bound_popup_enter: Callable
	var _bound_popup_exit: Callable
	var _bound_visibility_changed: Callable
	var _bound_tree_exiting_trigger: Callable
	var _bound_tree_exiting_popup: Callable
	var _bound_show_timer_timeout: Callable
	var _bound_hide_timer_timeout: Callable

	# Manager 引用（用于回调）
	var _manager: Node

	func _init(p_trigger: Control, p_flow_type: FlowType, p_data: Variant, p_delay: float, p_hide_grace: float, p_manager: Node) -> void:
		trigger = p_trigger
		flow_type = p_flow_type
		delay = p_delay
		hide_grace = p_hide_grace
		_manager = p_manager

		match flow_type:
			FlowType.POPUP_LEGACY:
				popup = p_data as Control
				delegate = PopupLegacyDelegate.new(p_manager)
				Logging.info("HoverPopupManager.HoverBinding: POPUP_LEGACY trigger=%s" % trigger.name)
			FlowType.SLIDE_FROM_RIGHT:
				delegate_data = p_data  # Dictionary
				delegate = SlideFromRightDelegate.new(p_manager)
				Logging.info("HoverPopupManager.HoverBinding: SLIDE_FROM_RIGHT trigger=%s" % trigger.name)
			FlowType.BELOW_OVERLAY:
				delegate_data = p_data  # Dictionary
				delegate = BelowOverlayDelegate.new(p_manager)
				Logging.info("HoverPopupManager.HoverBinding: BELOW_OVERLAY trigger=%s" % trigger.name)

	## ── 状态转移入口 ─────────────────────────────────
	func transition_to(new_state: State) -> bool:
		if state == new_state:
			return true
		if not _can_transition(state, new_state):
			Logging.err("HoverPopupManager: ILLEGAL transition %s → %s for trigger=%s" % [
				State.keys()[state], State.keys()[new_state], trigger.name
			])
			return false

		Logging.info("HoverPopupManager: trigger=%s %s → %s" % [
			trigger.name, State.keys()[state], State.keys()[new_state]
		])

		_exit_state(state)
		state = new_state
		_enter_state(new_state)
		return true

	## ── 紧急出口：绕过 guard 强制回到 IDLE ─────────────
	func force_to_idle() -> void:
		if state == State.IDLE:
			return
		Logging.info("HoverPopupManager: force_to_idle trigger=%s from %s" % [
			trigger.name, State.keys()[state]
		])
		_exit_state(state)
		state = State.IDLE
		_enter_state(State.IDLE)

	## ── Guard ────────────────────────────────────────
	func _can_transition(from_state: State, to_state: State) -> bool:
		match from_state:
			State.IDLE:
				return to_state == State.DELAYING
			State.DELAYING:
				return to_state == State.SHOWING or to_state == State.IDLE
			State.SHOWING:
				return to_state == State.HIDE_PENDING or to_state == State.IDLE
			State.HIDE_PENDING:
				return to_state == State.SHOWING or to_state == State.IDLE
		return false

	## ── Exit Actions ────────────────────────────────
	func _exit_state(old_state: State) -> void:
		match old_state:
			State.DELAYING:
				if show_timer and is_instance_valid(show_timer):
					show_timer.stop()
			State.SHOWING:
				# 🔧 不再在这里调 delegate.on_exit — UI 动画延迟到真正 IDLE 时执行
				pass
			State.HIDE_PENDING:
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.stop()

	## ── Entry Actions ───────────────────────────────
	func _enter_state(new_state: State) -> void:
		match new_state:
			State.IDLE:
				# 🆕 IDLE → 取消倒计时
				_manager._on_state_idle()
				# UI 退出：真正变为 IDLE 时才执行（hide_grace 延迟后）
				if delegate:
					delegate.on_exit(self)
				# 安全网：停止所有计时器
				if show_timer and is_instance_valid(show_timer):
					show_timer.stop()
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.stop()
				# 通知 Manager 清理 _current_active
				_manager._sync_current_active(self)

			State.DELAYING:
				if show_timer and is_instance_valid(show_timer):
					show_timer.start(delay)
					Logging.info("HoverPopupManager: DELAYING trigger=%s, show_timer=%.2fs" % [trigger.name, delay])
				else:
					Logging.err("HoverPopupManager: DELAYING but show_timer invalid for trigger=%s" % trigger.name)

			State.SHOWING:
				# 🆕 回到 SHOWING → 取消倒计时（如果是从 HIDE_PENDING 回来）
				_manager._on_state_show()
				if delegate:
					delegate.on_enter(self)
				else:
					Logging.err("HoverPopupManager: SHOWING but delegate is null for trigger=%s" % trigger.name)

			State.HIDE_PENDING:
				# 🆕 进入 HIDE_PENDING → 启动倒计时 UI
				_manager._on_state_hide_pending()
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.start(hide_grace)
					Logging.info("HoverPopupManager: HIDE_PENDING trigger=%s, hide_timer=%.2fs" % [trigger.name, hide_grace])
				else:
					Logging.err("HoverPopupManager: HIDE_PENDING but hide_timer invalid for trigger=%s" % trigger.name)

	# ── 事件处理（由 Manager 路由调用）─────────────────

	func on_mouse_enter_trigger() -> void:
		trigger_hovered = true
		if hide_timer and is_instance_valid(hide_timer):
			hide_timer.stop()

		match state:
			State.IDLE:
				transition_to(State.DELAYING)
			State.HIDE_PENDING:
				transition_to(State.SHOWING)

	func on_mouse_exit_trigger() -> void:
		trigger_hovered = false
		_maybe_hide()

	func on_mouse_enter_popup() -> void:
		popup_hovered = true
		if hide_timer and is_instance_valid(hide_timer):
			hide_timer.stop()

		match state:
			State.IDLE:
				transition_to(State.DELAYING)
			State.HIDE_PENDING:
				transition_to(State.SHOWING)

	func on_mouse_exit_popup() -> void:
		popup_hovered = false
		_maybe_hide()

	func on_show_timer_timeout() -> void:
		# 双检：超时时用户可能已经离开了
		if not trigger_hovered and not popup_hovered:
			Logging.info("HoverPopupManager: show timeout but user left, aborting trigger=%s" % trigger.name)
			transition_to(State.IDLE)
			return
		transition_to(State.SHOWING)

	func on_hide_timer_timeout() -> void:
		# 双检：超时时用户可能又回来了
		if trigger_hovered or popup_hovered:
			Logging.info("HoverPopupManager: hide timeout but user came back, aborting trigger=%s" % trigger.name)
			transition_to(State.SHOWING)
			return
		transition_to(State.IDLE)

	func _maybe_hide() -> void:
		if trigger_hovered or popup_hovered:
			return

		match state:
			State.DELAYING:
				Logging.info("HoverPopupManager: pre-show cancel for trigger=%s" % trigger.name)
				transition_to(State.IDLE)
			State.SHOWING:
				transition_to(State.HIDE_PENDING)
			State.IDLE, State.HIDE_PENDING:
				pass

# ── 成员变量 ─────────────────────────────────────────────

var _current_active: HoverBinding = null
var _bindings: Dictionary = {}  # trigger → HoverBinding
var _tooltip_layer: CanvasLayer
var _narrative_overlay_cache: Node = null  # 懒解析缓存

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 200
	add_child(_tooltip_layer)
	Logging.info("HoverPopupManager: initialized (v3 — FlowType delegates, NarrativeOverlay integration)")

# ── 懒解析 NarrativeOverlay ──────────────────────────────

## 通过绝对路径懒解析 NarrativeOverlay 实例，缓存结果。
## 返回 null 表示场景树尚未就绪或路径不存在。
func _get_narrative_overlay() -> Node:
	if _narrative_overlay_cache and is_instance_valid(_narrative_overlay_cache):
		return _narrative_overlay_cache
	var tree := get_tree()
	if not tree or not tree.root:
		Logging.info("HoverPopupManager._get_narrative_overlay: tree/root not ready")
		return null
	var main_node := tree.root.get_node_or_null("Main")
	if not main_node:
		Logging.info("HoverPopupManager._get_narrative_overlay: Main node not found")
		return null
	var overlay := main_node.get_node_or_null("TapeLayer/NarrativeOverlay")
	if overlay:
		_narrative_overlay_cache = overlay
		Logging.info("HoverPopupManager._get_narrative_overlay: cached NarrativeOverlay at %s" % overlay.get_path())
	else:
		Logging.info("HoverPopupManager._get_narrative_overlay: NarrativeOverlay not found at Main/TapeLayer/NarrativeOverlay")
	return overlay

# ── 🆕 状态机 → NarrativeOverlay 倒计时转发 ──────────

func _on_state_hide_pending() -> void:
	var overlay := _get_narrative_overlay()
	if overlay and overlay.has_method("_start_hover_countdown"):
		overlay._start_hover_countdown()

func _on_state_show() -> void:
	var overlay := _get_narrative_overlay()
	if overlay and overlay.has_method("_cancel_hover_countdown"):
		overlay._cancel_hover_countdown()

func _on_state_idle() -> void:
	var overlay := _get_narrative_overlay()
	if overlay and overlay.has_method("_cancel_hover_countdown"):
		overlay._cancel_hover_countdown()

# ── 公开 API ─────────────────────────────────────────────

## 注册一对 trigger ↔ 显示内容
## data:
##   POPUP_LEGACY:     Control（popup 节点）
##   SLIDE_FROM_RIGHT: Dictionary{"narrative": String, "vector": String}
##   BELOW_OVERLAY:    Dictionary{"narrative": String, "vector": String}
## delay: 悬停延迟（秒）
## hide_grace: 离开宽容时间（秒），action hover 建议 1.0s
## flow_type: 显示流类型
func register(trigger: Control, data: Variant, delay: float = 0.2, hide_grace: float = 0.15, flow_type: FlowType = FlowType.POPUP_LEGACY) -> void:
	if _bindings.has(trigger):
		Logging.warn("HoverPopupManager: trigger already registered, unregistering first")
		unregister(trigger)

	var binding := HoverBinding.new(trigger, flow_type, data, delay, hide_grace, self)

	# 创建 Timer（不自动启动）
	binding.show_timer = Timer.new()
	binding.show_timer.one_shot = true
	binding.show_timer.name = "ShowTimer"
	binding._bound_show_timer_timeout = _on_show_timer_timeout.bind(trigger)
	binding.show_timer.timeout.connect(binding._bound_show_timer_timeout)
	add_child(binding.show_timer)

	binding.hide_timer = Timer.new()
	binding.hide_timer.one_shot = true
	binding.hide_timer.name = "HideTimer"
	binding._bound_hide_timer_timeout = _on_hide_timer_timeout.bind(trigger)
	binding.hide_timer.timeout.connect(binding._bound_hide_timer_timeout)
	add_child(binding.hide_timer)

	# trigger 信号绑定（所有 flow 都需要）
	binding._bound_trigger_enter = _on_trigger_enter.bind(trigger)
	binding._bound_trigger_exit = _on_trigger_exit.bind(trigger)
	binding._bound_tree_exiting_trigger = _on_trigger_dying.bind(trigger)
	trigger.mouse_entered.connect(binding._bound_trigger_enter)
	trigger.mouse_exited.connect(binding._bound_trigger_exit)
	trigger.tree_exiting.connect(binding._bound_tree_exiting_trigger)

	# popup 信号绑定（仅 POPUP_LEGACY）
	if flow_type == FlowType.POPUP_LEGACY:
		var popup: Control = data as Control
		binding._bound_popup_enter = _on_popup_enter.bind(trigger)
		binding._bound_popup_exit = _on_popup_exit.bind(trigger)
		binding._bound_visibility_changed = _on_popup_visibility_changed.bind(trigger)
		binding._bound_tree_exiting_popup = _on_popup_dying.bind(weakref(trigger))
		popup.mouse_entered.connect(binding._bound_popup_enter)
		popup.mouse_exited.connect(binding._bound_popup_exit)
		popup.visibility_changed.connect(binding._bound_visibility_changed)
		popup.tree_exiting.connect(binding._bound_tree_exiting_popup)

		# 就地渲染：top_level = true
		if not popup.get_parent():
			_tooltip_layer.add_child(popup)
		popup.visible = false

	_bindings[trigger] = binding
	binding.state = HoverBinding.State.IDLE
	Logging.info("HoverPopupManager: registered trigger=%s flow_type=%d delay=%.2f hide_grace=%.2f" % [trigger.name, flow_type, delay, hide_grace])

## 取消注册
func unregister(trigger: Control) -> void:
	if not _bindings.has(trigger):
		return
	var binding: HoverBinding = _bindings[trigger]
	Logging.info("HoverPopupManager: unregistering trigger=%s" % trigger.name)

	# 如果正好是当前活跃的，强制隐藏
	if _current_active == binding:
		binding.force_to_idle()
		_current_active = null

	# 断开 trigger 信号（所有 flow）
	if is_instance_valid(trigger):
		trigger.mouse_entered.disconnect(binding._bound_trigger_enter)
		trigger.mouse_exited.disconnect(binding._bound_trigger_exit)
		trigger.tree_exiting.disconnect(binding._bound_tree_exiting_trigger)

	# 断开 popup 信号（仅 POPUP_LEGACY）
	if binding.flow_type == FlowType.POPUP_LEGACY:
		if is_instance_valid(binding.popup):
			binding.popup.mouse_entered.disconnect(binding._bound_popup_enter)
			binding.popup.mouse_exited.disconnect(binding._bound_popup_exit)
			binding.popup.visibility_changed.disconnect(binding._bound_visibility_changed)
			binding.popup.tree_exiting.disconnect(binding._bound_tree_exiting_popup)

	# 清理 Timer
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.timeout.disconnect(binding._bound_show_timer_timeout)
		binding.show_timer.queue_free()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.timeout.disconnect(binding._bound_hide_timer_timeout)
		binding.hide_timer.queue_free()

	# 清理 popup（仅 POPUP_LEGACY）
	if binding.flow_type == FlowType.POPUP_LEGACY and is_instance_valid(binding.popup):
		binding.popup.queue_free()

	_bindings.erase(trigger)

## 立即清除所有活跃 hover（行动开始时 / 新事件到来时 调用）
func dismiss_all() -> void:
	Logging.info("HoverPopupManager.dismiss_all: 清除所有活跃 hover（当前活跃=%s）" % (
		_current_active.trigger.name if _current_active and is_instance_valid(_current_active.trigger) else "null"
	))
	if _current_active != null:
		_current_active.force_to_idle()
		_current_active = null
	# 也遍历所有 binding，确保僵尸状态被清除
	for trigger in _bindings.keys():
		var binding: HoverBinding = _bindings.get(trigger)
		if binding and binding.state != HoverBinding.State.IDLE:
			binding.force_to_idle()
	Logging.info("HoverPopupManager.dismiss_all: 完成")

# ── 事件处理（Manager 纯路由层）────────────────────────

func _on_trigger_enter(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return

	binding.on_mouse_enter_trigger()

	if binding.state == HoverBinding.State.DELAYING:
		_request_show(binding)

func _on_trigger_exit(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return
	binding.on_mouse_exit_trigger()
	_sync_current_active(binding)

func _on_popup_enter(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return
	binding.on_mouse_enter_popup()

	if binding.state == HoverBinding.State.DELAYING:
		_request_show(binding)

func _on_popup_exit(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return
	binding.on_mouse_exit_popup()
	_sync_current_active(binding)

# ── 核心逻辑：全局互斥锁 ─────────────────────────────────

func _request_show(binding: HoverBinding) -> void:
	# 🩺 僵尸检测：_current_active 可能引用了已释放的 popup
	if _current_active != null:
		var zombie: bool = false
		if _current_active.flow_type == FlowType.POPUP_LEGACY and not is_instance_valid(_current_active.popup):
			zombie = true
		if zombie:
			Logging.err("HoverPopupManager: ZOMBIE _current_active detected! trigger=%s, forcing clear" % (
				_current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
			))
			_current_active = null

	# 已经在显示这个 binding，无需操作
	if _current_active == binding:
		if binding.flow_type == FlowType.POPUP_LEGACY:
			if is_instance_valid(binding.popup) and binding.popup.visible:
				return
		else:
			# 非 legacy flow 已活跃，无需重复
			return

	# 互斥锁：抢占当前活跃的 popup
	if _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: preempting %s for %s" % [active_name, binding.trigger.name])
		_current_active.force_to_idle()
		_current_active = null

	_current_active = binding

func _sync_current_active(binding: HoverBinding) -> void:
	if binding.state == HoverBinding.State.IDLE and _current_active == binding:
		_current_active = null

# ── Timer 回调（接收 trigger，反向查找 binding）─────────

func _on_show_timer_timeout(trigger: Control) -> void:
	if not is_instance_valid(trigger):
		Logging.info("HoverPopupManager: show_timer timeout but trigger freed, skip")
		return
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		Logging.info("HoverPopupManager: show_timer timeout but binding gone for trigger=%s" % trigger.name)
		return
	binding.on_show_timer_timeout()
	_sync_current_active(binding)

func _on_hide_timer_timeout(trigger: Control) -> void:
	if not is_instance_valid(trigger):
		Logging.info("HoverPopupManager: hide_timer timeout but trigger freed, skip")
		return
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		Logging.info("HoverPopupManager: hide_timer timeout but binding gone for trigger=%s" % trigger.name)
		return
	binding.on_hide_timer_timeout()
	_sync_current_active(binding)

# ── 定位（仅 POPUP_LEGACY 使用）───────────────────────────

const POPUP_PADDING: float = 12.0

func _position_popup_at_mouse(binding: HoverBinding) -> void:
	var popup = binding.popup
	var viewport := get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size

	popup.anchors_preset = Control.PRESET_TOP_LEFT

	var popup_size = popup.size
	if popup_size.x <= 0 or popup_size.y <= 0:
		popup_size = popup.custom_minimum_size
	if popup_size.x <= 0: popup_size.x = 320
	if popup_size.y <= 0: popup_size.y = 200

	var candidates := [
		{"x": mouse_pos.x + POPUP_PADDING, "y": mouse_pos.y + POPUP_PADDING,
		 "right": mouse_pos.x + POPUP_PADDING + popup_size.x, "bottom": mouse_pos.y + POPUP_PADDING + popup_size.y,
		 "pref": 4},
		{"x": mouse_pos.x + POPUP_PADDING, "y": mouse_pos.y - popup_size.y - POPUP_PADDING,
		 "right": mouse_pos.x + POPUP_PADDING + popup_size.x, "bottom": mouse_pos.y - POPUP_PADDING,
		 "pref": 3},
		{"x": mouse_pos.x - popup_size.x - POPUP_PADDING, "y": mouse_pos.y + POPUP_PADDING,
		 "right": mouse_pos.x - POPUP_PADDING, "bottom": mouse_pos.y + POPUP_PADDING + popup_size.y,
		 "pref": 2},
		{"x": mouse_pos.x - popup_size.x - POPUP_PADDING, "y": mouse_pos.y - popup_size.y - POPUP_PADDING,
		 "right": mouse_pos.x - POPUP_PADDING, "bottom": mouse_pos.y - POPUP_PADDING,
		 "pref": 1},
	]

	var best = null
	for c in candidates:
		if c["x"] >= 0 and c["y"] >= 0 and c["right"] <= viewport_size.x and c["bottom"] <= viewport_size.y:
			best = c
			break

	if best == null:
		for c in candidates:
			var tx = clamp(c["x"], 0.0, viewport_size.x - popup_size.x)
			var ty = clamp(c["y"], 0.0, viewport_size.y - popup_size.y)
			best = { "x": tx, "y": ty, "pref": c["pref"] }
			break

	popup.position = Vector2(best["x"], best["y"])
	Logging.info("HoverPopupManager: positioned popup at (%d, %d) (pref=%d, size=%s)" % [best["x"], best["y"], best["pref"], popup_size])

# ── 越权拦截（仅 POPUP_LEGACY）────────────────────────────

func _on_popup_visibility_changed(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return
	var popup = binding.popup
	if not is_instance_valid(popup):
		return
	if popup.visible and _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: popup '%s' shown while '%s' is active, forcing hide" % [popup.name, active_name])
		popup.visible = false

# ── 自动收尸 ─────────────────────────────────────────────

func _on_trigger_dying(trigger: Control) -> void:
	unregister(trigger)

func _on_popup_dying(trigger_ref: Variant) -> void:
	var trigger = trigger_ref.get_ref() if trigger_ref else null
	if not trigger or not is_instance_valid(trigger):
		Logging.info("HoverPopupManager: popup dying but trigger already freed, skip cleanup")
		return
	Logging.info("HoverPopupManager: popup for trigger=%s tree_exiting" % trigger.name)
	if _bindings.has(trigger):
		unregister(trigger)

# ── 🆕 外部代理入口（由 NarrativeOverlay.hover_container 调用）──

## 鼠标进入 hover_container → 等同于还在原 trigger 上方
func _on_proxy_enter() -> void:
	if _current_active != null:
		_current_active.on_mouse_enter_popup()

## 鼠标离开 hover_container → 等同于离开原 trigger 热区
func _on_proxy_exit() -> void:
	if _current_active != null:
		_current_active.on_mouse_exit_popup()
