extends Node
const _HoverInfoPopup = preload("res://ui/hover_info_popup.gd")

## P社式 Hover 延迟弹出管理器（Autoload）v2.0
##
## 用法:
##   HoverPopupManager.register(my_button, my_popup, 0.5, 0.15)
##
## 状态机（HoverBinding 自治）:
##   IDLE → DELAYING → SHOWING → HIDE_PENDING → IDLE
##
## 四地雷防御:
##   1. tree_exiting 自动 unregister（幽灵引用）
##   2. 全局 _current_active 互斥锁（并发抢占）
##   3. top_level 就地渲染（零侵入 UI 继承链，屏幕坐标直接对齐）
##   4. Timer 回调绑定 trigger（非 binding），免疫悬空引用

# ── 内部数据结构：自治状态机 ─────────────────────────────

class HoverBinding:
	enum State { IDLE, DELAYING, SHOWING, HIDE_PENDING }

	var trigger: Control
	var popup: Control
	var delay: float = 0.2          # 悬停多久后弹出
	var hide_grace: float = 0.15    # 离开热区后容忍多久隐藏
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

	# Manager 引用（用于回调 _position_popup_at_mouse 和 _sync_current_active）
	var _manager: Node

	func _init(p_trigger: Control, p_popup: Control, p_delay: float, p_hide_grace: float, p_manager: Node) -> void:
		trigger = p_trigger
		popup = p_popup
		delay = p_delay
		hide_grace = p_hide_grace
		_manager = p_manager

	## ── 状态转移入口 ─────────────────────────────────
	## 所有状态变更必须经过此方法。非法转换会被 Logging.err 拦截并返回 false。
	func transition_to(new_state: State) -> bool:
		if state == new_state:
			return true
		if not _can_transition(state, new_state):
			Logging.err("HoverPopupManager: ILLEGAL transition %s → %s for trigger=%s" % [
				State.keys()[state], State.keys()[new_state], trigger.name
			])
			return false

		Logging.debug("HoverPopupManager: trigger=%s %s → %s" % [
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
		Logging.debug("HoverPopupManager: force_to_idle trigger=%s from %s" % [
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
				if is_instance_valid(popup):
					popup.visible = false
					Logging.debug("HoverPopupManager: hiding popup=%s (exit SHOWING)" % popup.name)
			State.HIDE_PENDING:
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.stop()

	## ── Entry Actions ───────────────────────────────
	func _enter_state(new_state: State) -> void:
		match new_state:
			State.IDLE:
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
					Logging.debug("HoverPopupManager: DELAYING trigger=%s, show_timer=%.2fs" % [trigger.name, delay])
				else:
					Logging.err("HoverPopupManager: DELAYING but show_timer invalid for trigger=%s" % trigger.name)

			State.SHOWING:
				if not is_instance_valid(popup):
					Logging.err("HoverPopupManager: SHOWING but popup freed for trigger=%s, forcing IDLE" % trigger.name)
					transition_to(State.IDLE)
					return
				_manager._position_popup_at_mouse(self)
				popup.z_index = 100
				popup.visible = true
				Logging.debug("HoverPopupManager: showing popup=%s at position %s, size=%s, z_index=%d" % [
					popup.name, popup.position, popup.size, popup.z_index
				])

			State.HIDE_PENDING:
				if hide_timer and is_instance_valid(hide_timer):
					hide_timer.start(hide_grace)
					Logging.debug("HoverPopupManager: HIDE_PENDING trigger=%s, hide_timer=%.2fs" % [trigger.name, hide_grace])
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
				Logging.debug("HoverPopupManager: pre-show cancel for trigger=%s" % trigger.name)
				transition_to(State.IDLE)
			State.SHOWING:
				transition_to(State.HIDE_PENDING)
			State.IDLE, State.HIDE_PENDING:
				pass  # 已在终态或过渡态

# ── 成员变量 ─────────────────────────────────────────────

var _current_active: HoverBinding = null
var _bindings: Dictionary = {}  # trigger → HoverBinding

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	Logging.info("HoverPopupManager: initialized (v2 — top_level rendering, autonomous state machine)")

# ── 公开 API ─────────────────────────────────────────────

## 注册一对 trigger ↔ popup
## delay: 悬停延迟（秒），默认 0.5
## hide_grace: 离开宽容时间（秒），默认 0.15
func register(trigger: Control, popup: Control, delay: float = 0.2, hide_grace: float = 0.15) -> void:
	if _bindings.has(trigger):
		Logging.warn("HoverPopupManager: trigger already registered, unregistering first")
		unregister(trigger)

	var binding := HoverBinding.new(trigger, popup, delay, hide_grace, self)

	# 创建 Timer（不自动启动）
	# ⚠️ Timer 回调绑定 trigger（非 binding），从 _bindings 反向查找，天然免疫悬空引用
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

	# 信号绑定 —— 回调统一传 trigger，Manager 从 _bindings 反向查找
	binding._bound_trigger_enter = _on_trigger_enter.bind(trigger)
	binding._bound_trigger_exit = _on_trigger_exit.bind(trigger)
	binding._bound_popup_enter = _on_popup_enter.bind(trigger)
	binding._bound_popup_exit = _on_popup_exit.bind(trigger)
	binding._bound_visibility_changed = _on_popup_visibility_changed.bind(trigger)
	binding._bound_tree_exiting_trigger = _on_trigger_dying.bind(trigger)
	binding._bound_tree_exiting_popup = _on_popup_dying.bind(weakref(trigger))

	trigger.mouse_entered.connect(binding._bound_trigger_enter)
	trigger.mouse_exited.connect(binding._bound_trigger_exit)
	popup.mouse_entered.connect(binding._bound_popup_enter)
	popup.mouse_exited.connect(binding._bound_popup_exit)
	popup.visibility_changed.connect(binding._bound_visibility_changed)
	trigger.tree_exiting.connect(binding._bound_tree_exiting_trigger)
	popup.tree_exiting.connect(binding._bound_tree_exiting_popup)

	# 就地渲染：top_level = true 使 popup 在屏幕坐标中渲染，完全脱离父节点 Transform。
	# 零侵入 UI 继承链 — Theme、Control Scale、owner 全部保留在原始父节点下。
	# ⚠️ 绝不 reparent：reparent 会触发 tree_exiting → _on_popup_dying → unregister，
	#   导致刚注册的 binding 被立刻销毁。top_level 不需要变更父节点。
	# ⚠️ 孤儿节点（HoverInfoPopup.new()）直接 add_child，无 tree_exiting 风险。
	if not popup.get_parent():
		add_child(popup)
	popup.top_level = true
	popup.visible = false

	_bindings[trigger] = binding
	binding.state = HoverBinding.State.IDLE
	Logging.debug("HoverPopupManager: registered trigger=%s popup=%s delay=%.2f hide_grace=%.2f" % [trigger.name, popup.name, delay, hide_grace])

## 取消注册
func unregister(trigger: Control) -> void:
	if not _bindings.has(trigger):
		return
	var binding: HoverBinding = _bindings[trigger]
	Logging.debug("HoverPopupManager: unregistering trigger=%s" % trigger.name)

	# 如果正好是当前活跃的，强制隐藏
	if _current_active == binding:
		binding.force_to_idle()
		_current_active = null

	# 断开信号（如果节点还活着）
	# 使用绑定时保存的 Callable 以精确匹配 .bind() 包装
	if is_instance_valid(trigger):
		trigger.mouse_entered.disconnect(binding._bound_trigger_enter)
		trigger.mouse_exited.disconnect(binding._bound_trigger_exit)
		trigger.tree_exiting.disconnect(binding._bound_tree_exiting_trigger)
	if is_instance_valid(binding.popup):
		binding.popup.mouse_entered.disconnect(binding._bound_popup_enter)
		binding.popup.mouse_exited.disconnect(binding._bound_popup_exit)
		binding.popup.visibility_changed.disconnect(binding._bound_visibility_changed)
		binding.popup.tree_exiting.disconnect(binding._bound_tree_exiting_popup)

	# 清理 Timer（断开信号 + 释放）
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.timeout.disconnect(binding._bound_show_timer_timeout)
		binding.show_timer.queue_free()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.timeout.disconnect(binding._bound_hide_timer_timeout)
		binding.hide_timer.queue_free()

	# 清理 popup
	if is_instance_valid(binding.popup):
		binding.popup.queue_free()

	_bindings.erase(trigger)

# ── 事件处理（Manager 纯路由层）────────────────────────

## 路由层不碰 Timer 或 visible，只做：
##   1. 从 _bindings 反向查找 binding
##   2. 委托 binding 的事件处理方法
##   3. 调用 _request_show / _sync_current_active 维护全局互斥锁

func _on_trigger_enter(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return

	binding.on_mouse_enter_trigger()

	# 如果刚进入 DELAYING 状态，发起全局互斥请求
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

## 发起显示请求，处理全局互斥抢占
func _request_show(binding: HoverBinding) -> void:
	# 🩺 僵尸检测：_current_active 可能引用了已释放的 popup
	if _current_active != null and not is_instance_valid(_current_active.popup):
		Logging.err("HoverPopupManager: ZOMBIE _current_active detected! trigger=%s, forcing clear" % (
			_current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		))
		_current_active = null

	# 已经在显示这个 popup，无需操作
	if _current_active == binding and is_instance_valid(binding.popup) and binding.popup.visible:
		return

	# 互斥锁：抢占当前活跃的 popup
	if _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: preempting %s for %s" % [active_name, binding.trigger.name])
		_current_active.force_to_idle()
		_current_active = null

	_current_active = binding

## 同步 _current_active：如果 binding 已回到 IDLE，清理全局指针
func _sync_current_active(binding: HoverBinding) -> void:
	if binding.state == HoverBinding.State.IDLE and _current_active == binding:
		_current_active = null

# ── Timer 回调（接收 trigger，反向查找 binding）─────────

func _on_show_timer_timeout(trigger: Control) -> void:
	if not is_instance_valid(trigger):
		Logging.debug("HoverPopupManager: show_timer timeout but trigger freed, skip")
		return
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		Logging.debug("HoverPopupManager: show_timer timeout but binding gone for trigger=%s" % trigger.name)
		return
	binding.on_show_timer_timeout()
	_sync_current_active(binding)

func _on_hide_timer_timeout(trigger: Control) -> void:
	if not is_instance_valid(trigger):
		Logging.debug("HoverPopupManager: hide_timer timeout but trigger freed, skip")
		return
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		Logging.debug("HoverPopupManager: hide_timer timeout but binding gone for trigger=%s" % trigger.name)
		return
	binding.on_hide_timer_timeout()
	_sync_current_active(binding)

# ── 定位 ─────────────────────────────────────────────────

## 将 popup 定位到鼠标指针位置，智能四象限定位避免被遮挡
## top_level = true 时 popup.position 直接对齐屏幕坐标，无需矩阵变换
## 优先级：右下 → 右上 → 左下 → 左上
const POPUP_PADDING: float = 12.0

func _position_popup_at_mouse(binding: HoverBinding) -> void:
	var popup = binding.popup
	var viewport := get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size

	# 重置锚点为左上角
	popup.anchors_preset = Control.PRESET_TOP_LEFT

	# 获取 popup 实际尺寸（可能为 0，回退到 custom_minimum_size）
	var popup_size = popup.size
	if popup_size.x <= 0 or popup_size.y <= 0:
		popup_size = popup.custom_minimum_size
	if popup_size.x <= 0: popup_size.x = 320
	if popup_size.y <= 0: popup_size.y = 200

	# 四象限候选位置（优先级：右下 → 右上 → 左下 → 左上）
	var candidates := [
		# 1. 右下
		{ "x": mouse_pos.x + POPUP_PADDING, "y": mouse_pos.y + POPUP_PADDING,
		  "right": mouse_pos.x + POPUP_PADDING + popup_size.x, "bottom": mouse_pos.y + POPUP_PADDING + popup_size.y,
		  "pref": 4 },
		# 2. 右上
		{ "x": mouse_pos.x + POPUP_PADDING, "y": mouse_pos.y - popup_size.y - POPUP_PADDING,
		  "right": mouse_pos.x + POPUP_PADDING + popup_size.x, "bottom": mouse_pos.y - POPUP_PADDING,
		  "pref": 3 },
		# 3. 左下
		{ "x": mouse_pos.x - popup_size.x - POPUP_PADDING, "y": mouse_pos.y + POPUP_PADDING,
		  "right": mouse_pos.x - POPUP_PADDING, "bottom": mouse_pos.y + POPUP_PADDING + popup_size.y,
		  "pref": 2 },
		# 4. 左上
		{ "x": mouse_pos.x - popup_size.x - POPUP_PADDING, "y": mouse_pos.y - popup_size.y - POPUP_PADDING,
		  "right": mouse_pos.x - POPUP_PADDING, "bottom": mouse_pos.y - POPUP_PADDING,
		  "pref": 1 },
	]

	var best = null
	for c in candidates:
		# 检查是否完全在屏幕内
		if c["x"] >= 0 and c["y"] >= 0 and c["right"] <= viewport_size.x and c["bottom"] <= viewport_size.y:
			best = c
			break

	# 如果没有候选完全在屏幕内，fallback：按优先级选，然后 clamp
	if best == null:
		for c in candidates:
			var tx = clamp(c["x"], 0.0, viewport_size.x - popup_size.x)
			var ty = clamp(c["y"], 0.0, viewport_size.y - popup_size.y)
			best = { "x": tx, "y": ty, "pref": c["pref"] }
			break

	popup.position = Vector2(best["x"], best["y"])
	Logging.debug("HoverPopupManager: positioned popup at (%d, %d) (pref=%d, size=%s)" % [best["x"], best["y"], best["pref"], popup_size])

# ── 越权拦截 ─────────────────────────────────────────────

## popup 被外部代码 set visible=true 时，如果当前有其他活跃 popup，强制隐藏
func _on_popup_visibility_changed(trigger: Control) -> void:
	var binding: HoverBinding = _bindings.get(trigger)
	if not binding:
		return
	var popup = binding.popup
	if not is_instance_valid(popup):
		return
	if popup.visible and _current_active != null and _current_active != binding:
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.debug("HoverPopupManager: popup '%s' shown while '%s' is active, forcing hide" % [popup.name, active_name])
		popup.visible = false

# ── 自动收尸 ─────────────────────────────────────────────

func _on_trigger_dying(trigger: Control) -> void:
	# trigger tree_exiting 时同步清理（不能用 call_deferred，节点即将释放）
	unregister(trigger)

func _on_popup_dying(trigger_ref: Variant) -> void:
	# popup 挂了也清理对应的 trigger 注册
	# ⚠️ trigger 参数为 weakref — tree_exiting 时原 trigger 可能已 freed
	var trigger = trigger_ref.get_ref() if trigger_ref else null
	if not trigger or not is_instance_valid(trigger):
		Logging.debug("HoverPopupManager: popup dying but trigger already freed, skip cleanup")
		return
	Logging.debug("HoverPopupManager: popup for trigger=%s tree_exiting" % trigger.name)
	if _bindings.has(trigger):
		unregister(trigger)
