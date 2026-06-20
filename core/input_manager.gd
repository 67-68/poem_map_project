extends Node
class_name InputManager

## InputManager — 全局快捷键总线
## 职责：统一拦截 Space / 1-4 / Esc / Tab / PageUp / PageDown
## 通过 _input 在 _unhandled_input 之前消费事件，确保暂停时也能响应
##
## 注册模式：
##   - register_number_key_callbacks(callbacks: Array[Callable])
##   - unregister_number_key_callbacks()
##   - register_scroll_container(sc: SmoothScrollContainer)
##   - unregister_scroll_container()

# ── 1-4 数字键回调 ──────────────────────────────────
var _number_key_callbacks: Array[Callable] = []
# 哪个系统注册了回调（用于日志和防御）
var _number_key_owner: String = ""

# ── 纸带 ScrollContainer（供 PgUp/PgDn）───────────────
var _active_scroll: SmoothScrollContainer = null

# ── 系统菜单打开时屏蔽除 Esc 外的所有键 ──────────────
var _system_menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ═══════════════════════════════════════════════
# _input — 全局键盘拦截（先于 _unhandled_input）
# ═══════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# ── 系统菜单模式：只放行 Esc（关闭菜单）──
	if _system_menu_open:
		if event.keycode == KEY_ESCAPE:
			Logging.info("InputManager: Esc — 关闭系统菜单")
			_toggle_system_menu(false)
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_SPACE:
			_on_space()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var idx = event.keycode - KEY_1  # 0-based
			_on_number_key(idx)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_on_esc()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_on_tab()
			get_viewport().set_input_as_handled()
		KEY_PAGEUP:
			_on_page_up()
			get_viewport().set_input_as_handled()
		KEY_PAGEDOWN:
			_on_page_down()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════
# Space — 拨弄时间（暂停/继续）
# ═══════════════════════════════════════════════

func _on_space() -> void:
	if TimeService.time_start:
		Logging.info("InputManager: Space → TimeService.pause()")
		TimeService.pause()
	else:
		Logging.info("InputManager: Space → TimeService.play()")
		TimeService.play()


# ═══════════════════════════════════════════════
# 1-4 — 命运的抉择
# ═══════════════════════════════════════════════

func _on_number_key(idx: int) -> void:
	if _number_key_callbacks.is_empty():
		Logging.debug("InputManager: 数字键 %d 按下，但无注册回调" % (idx + 1))
		return

	if idx >= _number_key_callbacks.size():
		Logging.debug("InputManager: 数字键 %d 超出回调数量 %d（owner=%s）" % [idx + 1, _number_key_callbacks.size(), _number_key_owner])
		return

	var cb: Callable = _number_key_callbacks[idx]
	if not cb.is_valid():
		Logging.warn("InputManager: 数字键 %d 的回调无效（owner=%s）" % [idx + 1, _number_key_owner])
		return

	Logging.info("InputManager: 数字键 %d → 调用回调（owner=%s）" % [idx + 1, _number_key_owner])
	cb.call()


## 注册 1-4 数字键回调数组
## owner_name: 用于日志的可读标识（如 "NarrativeOverlay" / "DecisionScroll" / "FocusChat"）
func register_number_key_callbacks(callbacks: Array[Callable], owner_name: String = "") -> void:
	Logging.info("InputManager.register_number_key_callbacks: owner='%s' count=%d" % [owner_name, callbacks.size()])
	_number_key_callbacks = callbacks
	_number_key_owner = owner_name


## 清空 1-4 数字键回调（选项已被选择/离开区域时调用）
func unregister_number_key_callbacks(owner_name: String = "") -> void:
	Logging.info("InputManager.unregister_number_key_callbacks: owner='%s' (was '%s')" % [owner_name, _number_key_owner])
	_number_key_callbacks.clear()
	_number_key_owner = ""


# ═══════════════════════════════════════════════
# Esc — 遁入虚无（系统菜单）
# ═══════════════════════════════════════════════

func _on_esc() -> void:
	Logging.info("InputManager: Esc → 打开系统菜单")
	_toggle_system_menu(true)


func _toggle_system_menu(open: bool) -> void:
	_system_menu_open = open

	var system_menu := _get_system_menu()
	if not system_menu:
		Logging.err("InputManager._toggle_system_menu: 无法找到 SystemMenu 节点")
		return

	if open:
		system_menu.open_menu()
	else:
		system_menu.close_menu()

# ═══════════════════════════════════════════════
# Tab — 纯地图模式 toggle
# ═══════════════════════════════════════════════

func _on_tab() -> void:
	Logging.info("InputManager: Tab → toggle 纯地图模式")
	EventBus.request_toggle_map_only.emit()


# ═══════════════════════════════════════════════
# PageUp / PageDown — 翻阅卷宗
# ═══════════════════════════════════════════════

func _on_page_up() -> void:
	_scroll_page(-1)


func _on_page_down() -> void:
	_scroll_page(1)


func _scroll_page(direction: int) -> void:
	if not _active_scroll:
		Logging.debug("InputManager: PageUp/Down 按下，但无注册 ScrollContainer")
		return

	Logging.debug("InputManager: Page%s → SmoothScrollContainer.scroll_page(%d)" % [
		"Up" if direction < 0 else "Down", direction
	])
	_active_scroll.scroll_page(direction)


# ═══════════════════════════════════════════════
# 注册/注销 — ScrollContainer（供 PgUp/PgDn）
# ═══════════════════════════════════════════════

func register_scroll_container(sc: SmoothScrollContainer) -> void:
	Logging.debug("InputManager.register_scroll_container: %s" % sc.get_path())
	_active_scroll = sc


func unregister_scroll_container() -> void:
	Logging.debug("InputManager.unregister_scroll_container")
	_active_scroll = null


# ═══════════════════════════════════════════════
# 内部 — 查找 SystemMenu 节点
# ═══════════════════════════════════════════════

func _get_system_menu() -> Node:
	# 通过场景树绝对路径查找（InputManager 在 CoreSystems 下，SystemMenu 在 TapeLayer 下）
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null

	# 路径：Main → TapeLayer → SystemMenu
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		Logging.err("InputManager: 无法找到 Main 节点")
		return null

	var tape_layer := main_node.get_node_or_null("TapeLayer")
	if not tape_layer:
		Logging.err("InputManager: 无法找到 TapeLayer 节点")
		return null

	var system_menu := tape_layer.get_node_or_null("SystemMenu")
	if not system_menu:
		Logging.err("InputManager: 无法找到 TapeLayer/SystemMenu 节点")
		return null

	return system_menu
