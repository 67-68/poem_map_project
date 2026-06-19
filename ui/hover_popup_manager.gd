extends Node

## P社式 Hover 延迟弹出管理器（Autoload）
##
## 用法:
##   HoverPopupManager.register(my_button, my_popup, 0.5, 0.15)
##
## 状态机:
##   IDLE → DELAYING → SHOWING → HIDE_PENDING → IDLE
##
## 三地雷防御:
##   1. tree_exited 自动 unregister（幽灵引用）
##   2. 全局 _current_active 互斥锁（并发抢占）
##   3. CanvasLayer(layer=120) 神之层（Z-Index 幻觉）

# ── 内部数据结构 ─────────────────────────────────────────

class HoverBinding:
	var trigger: Control
	var popup: Control
	var delay: float = 0.5          # 悬停多久后弹出
	var hide_grace: float = 0.15    # 离开热区后容忍多久隐藏
	var show_timer: Timer
	var hide_timer: Timer
	var trigger_hovered: bool = false
	var popup_hovered: bool = false
	
	func _init(p_trigger: Control, p_popup: Control, p_delay: float, p_hide_grace: float) -> void:
		trigger = p_trigger
		popup = p_popup
		delay = p_delay
		hide_grace = p_hide_grace

# ── 成员变量 ─────────────────────────────────────────────

var _canvas_layer: CanvasLayer
var _current_active: HoverBinding = null
var _bindings: Dictionary = {}  # trigger → HoverBinding

# ── 生命周期 ─────────────────────────────────────────────

func _ready() -> void:
	# 地雷三：创建神之层，保证 popup 永远在最顶层
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 120
	_canvas_layer.name = "HoverPopupCanvasLayer"
	add_child(_canvas_layer)
	Logging.info("HoverPopupManager: CanvasLayer(layer=120) created")

# ── 公开 API ─────────────────────────────────────────────

## 注册一对 trigger ↔ popup
## delay: 悬停延迟（秒），默认 0.5
## hide_grace: 离开宽容时间（秒），默认 0.15
func register(trigger: Control, popup: Control, delay: float = 0.5, hide_grace: float = 0.15) -> void:
	if _bindings.has(trigger):
		Logging.warn("HoverPopupManager: trigger already registered, unregistering first")
		unregister(trigger)
	
	var binding := HoverBinding.new(trigger, popup, delay, hide_grace)
	
	# 创建 Timer（不自动启动）
	binding.show_timer = Timer.new()
	binding.show_timer.one_shot = true
	binding.show_timer.name = "ShowTimer"
	binding.show_timer.timeout.connect(_on_show_timer_timeout.bind(binding))
	add_child(binding.show_timer)
	
	binding.hide_timer = Timer.new()
	binding.hide_timer.one_shot = true
	binding.hide_timer.name = "HideTimer"
	binding.hide_timer.timeout.connect(_on_hide_timer_timeout.bind(binding))
	add_child(binding.hide_timer)
	
	# 信号绑定
	trigger.mouse_entered.connect(_on_trigger_enter.bind(binding))
	trigger.mouse_exited.connect(_on_trigger_exit.bind(binding))
	popup.mouse_entered.connect(_on_popup_enter.bind(binding))
	popup.mouse_exited.connect(_on_popup_exit.bind(binding))
	
	# 越权拦截：popup 自己被外部代码 set visible=true 时强制执行状态机
	popup.visibility_changed.connect(_on_popup_visibility_changed.bind(binding))
	
	# 地雷一：自动收尸
	trigger.tree_exiting.connect(_on_trigger_dying.bind(trigger))
	popup.tree_exiting.connect(_on_popup_dying.bind(trigger))
	
	# 地雷三：把 popup reparent 到神之层
	popup.reparent(_canvas_layer)
	popup.visible = false
	# 延迟一帧再 enforcing，覆盖 popup 自身 _ready() 里的 show() 调用
	call_deferred("_enforce_hidden", binding)
	
	_bindings[trigger] = binding
	Logging.info("HoverPopupManager: registered trigger=%s popup=%s delay=%.2f hide_grace=%.2f" % [trigger.name, popup.name, delay, hide_grace])

## 取消注册
func unregister(trigger: Control) -> void:
	if not _bindings.has(trigger):
		return
	var binding: HoverBinding = _bindings[trigger]
	Logging.info("HoverPopupManager: unregistering trigger=%s" % trigger.name)
	
	# 如果正好是当前活跃的，强制隐藏
	if _current_active == binding:
		_hide_popup(binding)
	
	# 断开信号（如果节点还活着）
	if is_instance_valid(trigger):
		if trigger.mouse_entered.is_connected(_on_trigger_enter):
			trigger.mouse_entered.disconnect(_on_trigger_enter)
		if trigger.mouse_exited.is_connected(_on_trigger_exit):
			trigger.mouse_exited.disconnect(_on_trigger_exit)
	if is_instance_valid(binding.popup):
		if binding.popup.mouse_entered.is_connected(_on_popup_enter):
			binding.popup.mouse_entered.disconnect(_on_popup_enter)
		if binding.popup.mouse_exited.is_connected(_on_popup_exit):
			binding.popup.mouse_exited.disconnect(_on_popup_exit)
	
	# 清理 Timer
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.queue_free()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.queue_free()
	
	_bindings.erase(trigger)

# ── 事件处理 ─────────────────────────────────────────────

func _on_trigger_enter(binding: HoverBinding) -> void:
	binding.trigger_hovered = true
	
	# 取消正在进行的隐藏计时器
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.stop()
	
	_request_show(binding)

func _on_trigger_exit(binding: HoverBinding) -> void:
	binding.trigger_hovered = false
	_maybe_hide(binding)

func _on_popup_enter(binding: HoverBinding) -> void:
	binding.popup_hovered = true
	
	# 玩家移到了 popup 上，取消隐藏计时器
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.stop()

func _on_popup_exit(binding: HoverBinding) -> void:
	binding.popup_hovered = false
	_maybe_hide(binding)

# ── 核心逻辑 ─────────────────────────────────────────────

func _request_show(binding: HoverBinding) -> void:
	# 已经在显示这个 popup，无需操作
	if _current_active == binding and binding.popup.visible:
		return
	
	# 地雷二：互斥锁 — 强制隐藏当前活跃的 popup
	if _current_active != null and _current_active != binding:
		Logging.info("HoverPopupManager: preempting %s for %s" % [_current_active.trigger.name, binding.trigger.name])
		_hide_popup(_current_active)
	
	_current_active = binding
	
	# 启动延迟显示计时器
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.start(binding.delay)

func _on_show_timer_timeout(binding: HoverBinding) -> void:
	# 双检：超时时用户可能已经离开了
	if not binding.trigger_hovered and not binding.popup_hovered:
		Logging.info("HoverPopupManager: show timeout but user already left, aborting")
		return
	
	binding.popup.visible = true
	Logging.info("HoverPopupManager: showing popup=%s" % binding.popup.name)

func _maybe_hide(binding: HoverBinding) -> void:
	# 如果 trigger 或 popup 任一还在 hover，不隐藏
	if binding.trigger_hovered or binding.popup_hovered:
		return
	
	# 还没显示（在 DELAYING 阶段），直接取消
	if not binding.popup.visible:
		if binding.show_timer and is_instance_valid(binding.show_timer):
			binding.show_timer.stop()
		return
	
	# SHOWING 状态，启动隐藏宽容计时器
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.start(binding.hide_grace)

func _on_hide_timer_timeout(binding: HoverBinding) -> void:
	# 双检：超时时用户可能又回来了
	if binding.trigger_hovered or binding.popup_hovered:
		Logging.info("HoverPopupManager: hide timeout but user came back, aborting")
		return
	
	_hide_popup(binding)

func _hide_popup(binding: HoverBinding) -> void:
	if not is_instance_valid(binding.popup):
		return
	binding.popup.visible = false
	Logging.info("HoverPopupManager: hiding popup=%s" % binding.popup.name)
	
	# 停止所有计时器
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.stop()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.stop()
	
	if _current_active == binding:
		_current_active = null

# ── 越权拦截 ─────────────────────────────────────────────

## popup 自己被外部代码 set visible=true 时（如 ambition_hud.gd 里 show()），
## 如果当前没有 hover 状态，强制隐藏回去
func _on_popup_visibility_changed(binding: HoverBinding) -> void:
	var popup = binding.popup
	if not is_instance_valid(popup):
		return
	if popup.visible and _current_active != binding:
		Logging.info("HoverPopupManager: popup '%s' shown outside hover state machine, forcing hide" % popup.name)
		popup.visible = false

## register 后延迟一帧，覆盖 popup 自身 _ready() 里的 show()
func _enforce_hidden(binding: HoverBinding) -> void:
	if not is_instance_valid(binding.popup):
		return
	binding.popup.visible = false

# ── 地雷一：自动收尸 ─────────────────────────────────────

func _on_trigger_dying(trigger: Control) -> void:
	Logging.info("HoverPopupManager: trigger=%s tree_exiting, auto-unregistering" % trigger.name)
	# 用 call_deferred 避免在 tree_exiting 信号中修改同一帧的 _bindings
	call_deferred("unregister", trigger)

func _on_popup_dying(trigger: Control) -> void:
	# popup 挂了也清理对应的 trigger 注册
	Logging.info("HoverPopupManager: popup for trigger=%s tree_exiting" % trigger.name)
	if _bindings.has(trigger):
		call_deferred("unregister", trigger)
