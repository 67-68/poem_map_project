extends Node
const _HoverInfoPopup = preload("res://ui/hover_info_popup.gd")

## P社式 Hover 延迟弹出管理器（Autoload）v3.0
##
## 用法:
##   HoverPopupManager.register(my_button, popup, 0.2, 0.15, FlowType.POPUP_LEGACY)
##   HoverPopupManager.register(my_button, {"narrative":"...","vector":"..."}, 0.2, 1.0, FlowType.SLIDE_FROM_RIGHT)
##
## 状态机（HoverBinding 自治 v3.1 — 🆕 CROSSING 穿越宽容期）:
##   IDLE → DELAYING → SHOWING → HIDE_PENDING → IDLE
##   IDLE → CROSSING → DELAYING → ... (0.5s 穿越宽容期，已有活跃 SHOWING 时)
##   CROSSING → IDLE (快速离开，< 0.5s 不切换 hover)
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

enum FlowType { POPUP_LEGACY, SLIDE_FROM_RIGHT, BELOW_OVERLAY, SLIDE_FROM_LEFT }

## 🆕 穿越宽容期：鼠标从一个 hover 区域短暂掠过另一个区域时，不切换 hover
const CROSSING_GRACE: float = 0.5

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
## 🆕 不再使用滑动动画 — overlay 在 IDLE 态始终可见，hover 文本直接在 hover container 上切换。
## 行为等同于 BelowOverlayDelegate（直接显示/隐藏文本，不动 shadow_box）。
class SlideFromRightDelegate extends HoverDisplayDelegate:
	var _manager_ref: WeakRef

	func _init(manager: Node) -> void:
		_manager_ref = weakref(manager)

	func on_enter(binding) -> void:
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

		overlay.show_hover_text(narrative, vector)
		Logging.info("HoverPopupManager.SlideFromRightDelegate: hover text shown (direct, no animation)")

	func on_exit(_binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if overlay and overlay.has_method("hide_hover_text"):
			overlay.hide_hover_text()
			Logging.info("HoverPopupManager.SlideFromRightDelegate: hover text hidden (direct, no animation)")

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

## 🆕 不再使用滑动动画 — 行为等同于 BelowOverlayDelegate（直接显示/隐藏文本）。
class SlideFromLeftDelegate extends HoverDisplayDelegate:
	var _manager_ref: WeakRef

	func _init(manager: Node) -> void:
		_manager_ref = weakref(manager)

	func on_enter(binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if not overlay:
			Logging.err("HoverPopupManager.SlideFromLeftDelegate: NarrativeOverlay not found")
			return
		var text_data: Dictionary = binding.delegate_data if binding.delegate_data is Dictionary else {}
		var narrative: String = text_data.get("narrative", "")
		var vector: String = text_data.get("vector", "")
		overlay.show_hover_text(narrative, vector)
		Logging.info("HoverPopupManager.SlideFromLeftDelegate: hover text shown (direct, no animation)")

	func on_exit(_binding) -> void:
		var mgr = _manager_ref.get_ref()
		if not mgr:
			return
		var overlay = mgr._get_narrative_overlay()
		if overlay and overlay.has_method("hide_hover_text"):
			overlay.hide_hover_text()
			Logging.info("HoverPopupManager.SlideFromLeftDelegate: hover text hidden (direct, no animation)")

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
	enum State { IDLE, DELAYING, SHOWING, HIDE_PENDING, CROSSING }

	var trigger: Control
	var popup: Control = null          # 仅 POPUP_LEGACY 使用
	var delay: float = 0.2
	var hide_grace: float = 0.15
	var flow_type: FlowType = FlowType.POPUP_LEGACY
	var delegate: HoverDisplayDelegate
	var delegate_data: Variant          # Dictionary{narrative,vector} 或 null
	var show_timer: Timer
	var hide_timer: Timer
	var crossing_timer: Timer          # 🆕 穿越宽容期计时器
	var trigger_hovered: bool = false
	var popup_hovered: bool = false
	var state: State = State.IDLE
	var _skip_delegate_exit: bool = false  # 🆕 CROSSING→IDLE 时跳过 delegate.on_exit

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
	var _bound_crossing_timer_timeout: Callable  # 🆕

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
			FlowType.SLIDE_FROM_LEFT:
				delegate_data = p_data  # Dictionary
				delegate = SlideFromLeftDelegate.new(p_manager)
				Logging.info("HoverPopupManager.HoverBinding: SLIDE_FROM_LEFT trigger=%s" % trigger.name)

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
				return to_state == State.DELAYING or to_state == State.CROSSING
			State.DELAYING:
				return to_state == State.SHOWING or to_state == State.IDLE
			State.SHOWING:
				return to_state == State.HIDE_PENDING or to_state == State.IDLE
			State.HIDE_PENDING:
				return to_state == State.SHOWING or to_state == State.IDLE
			State.CROSSING:
				return to_state == State.DELAYING or to_state == State.IDLE
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
			State.CROSSING:
				if crossing_timer and is_instance_valid(crossing_timer):
					crossing_timer.stop()
				# 🐛 CROSSING 从未调用 delegate.on_enter，进入 IDLE 时跳过 delegate.on_exit
				_skip_delegate_exit = true

	## ── Entry Actions ───────────────────────────────
	func _enter_state(new_state: State) -> void:
		match new_state:
			State.IDLE:
				# 🆕 IDLE → 取消倒计时
				_manager._on_state_idle()
				# UI 退出：真正变为 IDLE 时才执行（hide_grace 延迟后）
				# 🐛 CROSSING 状态从未调用 delegate.on_enter，所以 CROSSING→IDLE 跳过 on_exit
				if delegate and not _skip_delegate_exit:
					delegate.on_exit(self)
				_skip_delegate_exit = false
				# 安全网：停止所有计时器
				if show_timer and is_instance_valid(show_timer):
					show_timer.stop()
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.stop()
				if crossing_timer and is_instance_valid(crossing_timer):
					crossing_timer.stop()
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
		
			State.CROSSING:
				# 🆕 穿越宽容期：启动 0.5s crossing_timer，到期后如果还在 crossing 则抢占
				if crossing_timer and is_instance_valid(crossing_timer):
					crossing_timer.start(CROSSING_GRACE)
					Logging.info("HoverPopupManager: CROSSING trigger=%s, crossing_timer=%.2fs" % [trigger.name, CROSSING_GRACE])
				else:
					Logging.err("HoverPopupManager: CROSSING but crossing_timer invalid for trigger=%s" % trigger.name)

	# ── 事件处理（由 Manager 路由调用）─────────────────

	func on_mouse_enter_trigger() -> void:
		trigger_hovered = true
		if hide_timer and is_instance_valid(hide_timer):
			hide_timer.stop()

		match state:
			State.IDLE:
				# 🆕 如果已有活跃 hover 在 SHOWING，进入 CROSSING 而非 DELAYING
				if _current_active_present():
					transition_to(State.CROSSING)
				else:
					transition_to(State.DELAYING)
			State.CROSSING:
				# 🆕 已经在 crossing 中，保持（可能之前被别的事覆盖后又回来了）
				pass
			State.HIDE_PENDING:
				transition_to(State.SHOWING)

	func on_mouse_exit_trigger() -> void:
		trigger_hovered = false
		# 🆕 CROSSING 状态下直接回 IDLE，不切换 hover
		if state == State.CROSSING:
			transition_to(State.IDLE)
			return
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

	## 🆕 检查 _manager 的 _current_active 是否在 SHOWING 或 HIDE_PENDING
	func _current_active_present() -> bool:
		var active = _manager._current_active
		if active == null or active == self:
			return false
		# 🐛 修复：鼠标从 A 移到 B 时，A 先 mouse_exited 进入 HIDE_PENDING，B 才 mouse_entered
		# 所以必须也检查 HIDE_PENDING
		return active.state == State.SHOWING or active.state == State.HIDE_PENDING

	## 🆕 crossing_timer 到期 → 抢占 _current_active，转入 DELAYING
	func _on_crossing_timer_timeout() -> void:
		# 双检：如果已经不在 CROSSING 状态（可能被 force_to_idle 提前清理），放弃
		if state != State.CROSSING:
			return
		# 双检：如果 _current_active 已经不是活跃状态（已被别的 binding 抢走），放弃
		var active = _manager._current_active
		if active == null or (active.state != State.SHOWING and active.state != State.HIDE_PENDING):
			Logging.info("HoverPopupManager: crossing timeout but _current_active no longer SHOWING/HIDE_PENDING, aborting trigger=%s" % trigger.name)
			transition_to(State.IDLE)
			return
		# 双检：用户可能已经离开了
		if not trigger_hovered and not popup_hovered:
			Logging.info("HoverPopupManager: crossing timeout but user left, aborting trigger=%s" % trigger.name)
			transition_to(State.IDLE)
			return

		Logging.info("HoverPopupManager: crossing timeout, preempting for trigger=%s" % trigger.name)
		# 抢占当前活跃
		_manager._preempt_current_active(self)
		# 转入 DELAYING（启动自身 show_timer）
		transition_to(State.DELAYING)

	func _maybe_hide() -> void:
		if trigger_hovered or popup_hovered:
			return

		match state:
			State.DELAYING:
				Logging.info("HoverPopupManager: pre-show cancel for trigger=%s" % trigger.name)
				transition_to(State.IDLE)
			State.SHOWING:
				transition_to(State.HIDE_PENDING)
			State.CROSSING:
				# 🆕 在 CROSSING 中离开 → 直接回 IDLE，不切换 hover
				transition_to(State.IDLE)
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

	# 🆕 穿越宽容期 Timer
	binding.crossing_timer = Timer.new()
	binding.crossing_timer.one_shot = true
	binding.crossing_timer.name = "CrossingTimer"
	binding._bound_crossing_timer_timeout = _on_crossing_timer_timeout.bind(trigger)
	binding.crossing_timer.timeout.connect(binding._bound_crossing_timer_timeout)
	add_child(binding.crossing_timer)

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

	# 🆕 清理 crossing_timer
	if binding.crossing_timer and is_instance_valid(binding.crossing_timer):
		binding.crossing_timer.timeout.disconnect(binding._bound_crossing_timer_timeout)
		binding.crossing_timer.queue_free()

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

	# 🆕 CROSSING 状态也需要调用 _request_show（它将跳过 _current_active 的立即抢占）
	if binding.state == HoverBinding.State.DELAYING or binding.state == HoverBinding.State.CROSSING:
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

	# 🆕 CROSSING 状态不执行立即抢占 — 等待 crossing_timer 到期后由 _on_crossing_timer_timeout 调用 _preempt_current_active
	if binding.state == HoverBinding.State.CROSSING:
		if _current_active == null or _current_active == binding:
			_current_active = binding
			return
		# 🐛 修复：如果 _current_active 在 HIDE_PENDING（鼠标已离开 A 但还没完全消失），
		# 必须把 A 拉回 SHOWING，否则 A 的 hide_timer 可能比 crossing_timer 先到期，
		# 导致 _current_active 变 null，crossing 白等
		if _current_active.state == HoverBinding.State.HIDE_PENDING:
			_current_active.transition_to(HoverBinding.State.SHOWING)
		# 如果 _current_active 另有其人（SHOWING），不做立即抢占
		return

	# 互斥锁：抢占当前活跃的 popup（仅 DELAYING→SHOWING 场景走到这里）
	if _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: preempting %s for %s" % [active_name, binding.trigger.name])
		_current_active.force_to_idle()
		_current_active = null

	_current_active = binding


## 🆕 由 crossing_timer 到期后调用，强制抢占当前活跃
func _preempt_current_active(binding: HoverBinding) -> void:
	if _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: _preempt_current_active: preempting %s for %s" % [active_name, binding.trigger.name])
		_current_active.force_to_idle()
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

## 🆕 crossing_timer 到期
func _on_crossing_timer_timeout(trigger: Control) -> void:
	if not is_instance_valid(trigger):
		Logging.info("HoverPopupManager: crossing_timer timeout but trigger freed, skip")
		return
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		Logging.info("HoverPopupManager: crossing_timer timeout but binding gone for trigger=%s" % trigger.name)
		return
	binding._on_crossing_timer_timeout()
	# _on_crossing_timer_timeout 内部调用了 _preempt_current_active，无需额外 _sync

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
