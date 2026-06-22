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
	enum State { IDLE, DELAYING, SHOWING, HIDE_PENDING }
	
	var trigger: Control
	var popup: Control
	var delay: float = 0.5          # 悬停多久后弹出
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
	_canvas_layer.layer = 129
	_canvas_layer.name = "HoverPopupCanvasLayer"
	add_child(_canvas_layer)
	Logging.info("HoverPopupManager: CanvasLayer(layer=129) created")

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
	
	# 信号绑定 —— 保存绑定的 Callable 以便 disconnect 时精确匹配
	binding._bound_trigger_enter = _on_trigger_enter.bind(binding)
	binding._bound_trigger_exit = _on_trigger_exit.bind(binding)
	binding._bound_popup_enter = _on_popup_enter.bind(binding)
	binding._bound_popup_exit = _on_popup_exit.bind(binding)
	binding._bound_visibility_changed = _on_popup_visibility_changed.bind(binding)
	binding._bound_tree_exiting_trigger = _on_trigger_dying.bind(trigger)
	binding._bound_tree_exiting_popup = _on_popup_dying.bind(weakref(trigger))
	
	trigger.mouse_entered.connect(binding._bound_trigger_enter)
	trigger.mouse_exited.connect(binding._bound_trigger_exit)
	popup.mouse_entered.connect(binding._bound_popup_enter)
	popup.mouse_exited.connect(binding._bound_popup_exit)
	
	# 越权拦截：popup 自己被外部代码 set visible=true 时强制执行状态机
	popup.visibility_changed.connect(binding._bound_visibility_changed)
	
	# 地雷一：自动收尸
	# ⚠️ 用 weakref 包裹 trigger — popup tree_exiting 时 trigger 可能已被释放
	# 无法做 Object→Control 类型转换
	trigger.tree_exiting.connect(binding._bound_tree_exiting_trigger)
	popup.tree_exiting.connect(binding._bound_tree_exiting_popup)
	
	# 地雷三：把 popup 添加到神之层
	# ⚠️ 不能用 reparent() — popup 由 HoverInfoPopup.new() 创建，无 parent
	# Godot 4 reparent() 要求节点必须有父节点，孤儿节点直接抛错
	_canvas_layer.add_child(popup)
	popup.visible = false
	# 延迟一帧再 enforcing，覆盖 popup 自身 _ready() 里的 show() 调用
	call_deferred("_enforce_hidden", binding)
	
	_bindings[trigger] = binding
	binding.state = HoverBinding.State.IDLE
	#Logging.info("HoverPopupManager: registered trigger=%s popup=%s delay=%.2f hide_grace=%.2f" % [trigger.name, popup.name, delay, hide_grace])

## 取消注册
func unregister(trigger: Control) -> void:
	if not _bindings.has(trigger):
		return
	var binding: HoverBinding = _bindings[trigger]
	# 🔇 降级为 DEBUG：正常生命周期事件，避免批量 free 时刷屏
	Logging.debug("HoverPopupManager: unregistering trigger=%s" % trigger.name)
	
	# 如果正好是当前活跃的，强制隐藏
	if _current_active == binding:
		_hide_popup(binding)
	
	# 断开信号（如果节点还活着）
	# 使用绑定时保存的 Callable 以精确匹配 .bind(binding) 包装
	if is_instance_valid(trigger):
		trigger.mouse_entered.disconnect(binding._bound_trigger_enter)
		trigger.mouse_exited.disconnect(binding._bound_trigger_exit)
		trigger.tree_exiting.disconnect(binding._bound_tree_exiting_trigger)
	if is_instance_valid(binding.popup):
		binding.popup.mouse_entered.disconnect(binding._bound_popup_enter)
		binding.popup.mouse_exited.disconnect(binding._bound_popup_exit)
		binding.popup.visibility_changed.disconnect(binding._bound_visibility_changed)
		binding.popup.tree_exiting.disconnect(binding._bound_tree_exiting_popup)
	
	# 清理 Timer
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.queue_free()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.queue_free()
	
	# 清理 popup（从 CanvasLayer 移除，防止僵尸节点累积阻挡鼠标事件）
	# ⚠️ queue_free 会在下一帧安全移除节点；不能在此处 remove_child
	# 因为 tree_exiting 信号触发时父节点正在修改子节点列表（blocked > 0）
	if is_instance_valid(binding.popup):
		binding.popup.queue_free()
	
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
	# 🩺 诊断：检查 _current_active 是否为僵尸 binding（popup 已 freed 但未清理）
	if _current_active != null and not is_instance_valid(_current_active.popup):
		Logging.err("HoverPopupManager: ZOMBIE _current_active detected! trigger=%s, forcing clear" % (
			_current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		))
		_current_active = null
	
	# 已经在显示这个 popup，无需操作
	if _current_active == binding and binding.popup.visible:
		return
	
	# 地雷二：互斥锁 — 强制隐藏当前活跃的 popup
	if _current_active != null and _current_active != binding:
		# 💀 防御僵尸节点：当前活跃的 trigger 可能正在被回收的路上
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		Logging.info("HoverPopupManager: preempting %s for %s" % [active_name, binding.trigger.name])
		_hide_popup(_current_active)
	
	_current_active = binding
	binding.state = HoverBinding.State.DELAYING
	
	# 启动延迟显示计时器
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.start(binding.delay)

func _on_show_timer_timeout(binding: HoverBinding) -> void:
	# 双检：超时时用户可能已经离开了
	if not binding.trigger_hovered and not binding.popup_hovered:
		Logging.info("HoverPopupManager: show timeout but user already left, aborting")
		return
	
	binding.state = HoverBinding.State.SHOWING
	_position_popup_at_mouse(binding)
	# z_index 兜底：当 reparent 到 _canvas_layer 失败时（popup 仍留在 UI CanvasLayer），
	# 高 z_index 确保 popup 渲染在 LeftPlayerPanel 等同级节点之上
	binding.popup.z_index = 100
	binding.popup.visible = true
	Logging.debug("HoverPopupManager: showing popup=%s at position %s, size=%s, parent=%s (layer=%d), z_index=%d" % [
		binding.popup.name,
		binding.popup.position,
		binding.popup.size,
		binding.popup.get_parent().name if binding.popup.get_parent() else "null",
		binding.popup.get_parent().layer if binding.popup.get_parent() is CanvasLayer else -999,
		binding.popup.z_index
	])

## 将 popup 定位到鼠标指针位置，clamp 到屏幕内（不低于屏幕上方）
func _position_popup_at_mouse(binding: HoverBinding) -> void:
	var popup = binding.popup
	# CanvasLayer 没有 get_global_mouse_position() / get_viewport_rect()
	# 使用 autoload Node.get_viewport() 获取 Viewport 引用
	var viewport := get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size
	
	# 重置锚点为左上角，避免父级 CanvasLayer 的 anchor 干扰
	popup.anchors_preset = Control.PRESET_TOP_LEFT
	
	# 获取 popup 实际尺寸（可能为 0，此时回退到 custom_minimum_size）
	var popup_size = popup.size
	if popup_size.x <= 0 or popup_size.y <= 0:
		popup_size = popup.custom_minimum_size
	# 如果仍然为 0，重设为合理默认值
	if popup_size.x <= 0: popup_size.x = 320
	if popup_size.y <= 0: popup_size.y = 200
	
	# 目标位置：鼠标右下方（偏移 10px，避免挡住 trigger）
	var target_x = mouse_pos.x + 10
	var target_y = mouse_pos.y + 10
	
	# clamp：不高于屏幕上方（y >= 0）
	target_y = max(0.0, target_y)
	# clamp 右边界
	if target_x + popup_size.x > viewport_size.x:
		target_x = mouse_pos.x - popup_size.x - 10
	# clamp 下边界
	if target_y + popup_size.y > viewport_size.y:
		target_y = mouse_pos.y - popup_size.y - 10
	# clamp 左边界（防止超出屏幕左侧）
	target_x = max(0.0, target_x)
	
	popup.position = Vector2(target_x, target_y)
	Logging.debug("HoverPopupManager: positioned popup at (%d, %d)" % [target_x, target_y])

func _maybe_hide(binding: HoverBinding) -> void:
	# 如果 trigger 或 popup 任一还在 hover，不隐藏
	if binding.trigger_hovered or binding.popup_hovered:
		return
	
	# 还没显示（在 DELAYING 阶段），直接取消
	if not binding.popup.visible:
		if binding.show_timer and is_instance_valid(binding.show_timer):
			binding.show_timer.stop()
		if _current_active == binding:
			_current_active = null
		binding.state = HoverBinding.State.IDLE
		return
	
	# SHOWING 状态，启动隐藏宽容计时器
	binding.state = HoverBinding.State.HIDE_PENDING
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.start(binding.hide_grace)

func _on_hide_timer_timeout(binding: HoverBinding) -> void:
	# 双检：超时时用户可能又回来了
	if binding.trigger_hovered or binding.popup_hovered:
		binding.state = HoverBinding.State.SHOWING
		Logging.info("HoverPopupManager: hide timeout but user came back, aborting")
		return
	
	_hide_popup(binding)

func _hide_popup(binding: HoverBinding) -> void:
	if not is_instance_valid(binding.popup):
		Logging.err("HoverPopupManager: _hide_popup called but popup already freed! _current_active was %s, forcing clear" % (
			"<SAME>" if _current_active == binding else "<DIFFERENT>"
		))
		# 🩹 即使 popup 已释放也必须清理 _current_active，防止状态机永久卡死
		if _current_active == binding:
			_current_active = null
		binding.state = HoverBinding.State.IDLE
		return
	binding.popup.visible = false
	Logging.debug("HoverPopupManager: hiding popup=%s" % binding.popup.name)
	
	# 停止所有计时器
	if binding.show_timer and is_instance_valid(binding.show_timer):
		binding.show_timer.stop()
	if binding.hide_timer and is_instance_valid(binding.hide_timer):
		binding.hide_timer.stop()
	
	binding.state = HoverBinding.State.IDLE
	if _current_active == binding:
		_current_active = null

# ── 越权拦截 ─────────────────────────────────────────────

## popup 自己被外部代码 set visible=true 时（如 ambition_hud.gd 里 show()），
## 如果当前没有 hover 状态，强制隐藏回去
func _on_popup_visibility_changed(binding: HoverBinding) -> void:
	var popup = binding.popup
	if not is_instance_valid(popup):
		return
	# 仅在已有其他活跃 popup 时才执行互斥拦截
	# 当 _current_active == null（无 hover 上下文）时，popup 自主显示不应被压制
	if popup.visible and _current_active != null and _current_active != binding:
		# 💀 同样的僵尸防御
		var active_name: String = _current_active.trigger.name if is_instance_valid(_current_active.trigger) else "<Freed_Zombie>"
		# 🔇 降级为 DEBUG：批量刷新时的正常竞争
		Logging.debug("HoverPopupManager: popup '%s' shown while '%s' is active, forcing hide" % [binding.popup.name, active_name])
		popup.visible = false

## register 后延迟一帧，覆盖 popup 自身 _ready() 里的 show()
func _enforce_hidden(binding: HoverBinding) -> void:
	if not is_instance_valid(binding.popup):
		return
	binding.popup.visible = false

# ── 地雷一：自动收尸 ─────────────────────────────────────

func _on_trigger_dying(trigger: Control) -> void:
	#Logging.info("HoverPopupManager: trigger=%s tree_exiting, auto-unregistering" % trigger.name)
	# ⚠️ 不能用 call_deferred — deferred 执行时 trigger 已被释放，Godot 无法转换参数类型
	# tree_exiting 信号中同步清理是安全的（节点还在但即将退出）
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
