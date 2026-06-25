extends Node
class_name InputManager

## InputManager — 全局快捷键总线
## 职责：统一拦截 1-4 / Esc / Tab / PageUp / PageDown
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
	Logging.info("InputManager._ready: 节点已就绪 path=%s process_mode=%d 树状态=%s paused=%s" % [
		get_path(), process_mode, is_inside_tree(), get_tree().paused if is_inside_tree() else "N/A"
	])


# ═══════════════════════════════════════════════
# _input — 全局键盘拦截（先于 _unhandled_input）
# ═══════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	# DEBUG: 追踪所有输入事件是否到达 InputManager
	if event is InputEventKey:
		Logging.debug("InputManager._input: keycode=%d pressed=%s echo=%s" % [event.keycode, event.pressed, event.echo])
	
	if not event is InputEventKey or not event.pressed:
		return

	# DEBUG: 确认 _input 通过了过滤条件
	Logging.debug("InputManager._input: 按键通过过滤 keycode=%d (SPACE=%d 1=%d ESC=%d TAB=%d PGUP=%d PGDN=%d)" % [
		event.keycode, KEY_SPACE, KEY_1, KEY_ESCAPE, KEY_TAB, KEY_PAGEUP, KEY_PAGEDOWN
	])

	# ── 系统菜单模式：只放行 Esc（关闭菜单）──
	if _system_menu_open:
		if event.keycode == KEY_ESCAPE:
			Logging.info("InputManager: Esc — 关闭系统菜单")
			_toggle_system_menu(false)
		get_viewport().set_input_as_handled()
		return

	# 使用 if/elif 链替代 match，避免 Godot 4 enum match 潜在问题
	var kc := event.keycode as int
	Logging.debug("InputManager._input: match前 keycode=%d" % kc)
	
	if kc >= KEY_1 and kc <= KEY_4:
		var idx = kc - KEY_1  # 0-based
		_on_number_key(idx)
		get_viewport().set_input_as_handled()
	elif kc == KEY_ESCAPE:
		_on_esc()
		get_viewport().set_input_as_handled()
	elif kc == KEY_TAB:
		_on_tab()
		get_viewport().set_input_as_handled()
	elif kc == KEY_PAGEUP:
		_on_page_up()
		get_viewport().set_input_as_handled()
	elif kc == KEY_PAGEDOWN:
		_on_page_down()
		get_viewport().set_input_as_handled()
	else:
		Logging.debug("InputManager._input: 未匹配任何快捷键 keycode=%d" % kc)


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
	# SystemMenu 挂载在 root/Main/SystemMenuLayer/SystemMenu
	var tree := get_tree()
	if not tree:
		return null
	var scene_root := tree.root
	if not scene_root:
		return null
	
	var main_node := scene_root.get_node_or_null("Main")
	if not main_node:
		Logging.err("InputManager: 无法找到 Main 节点")
		return null
	
	var system_menu_layer := main_node.get_node_or_null("SystemMenuLayer")
	if not system_menu_layer:
		Logging.err("InputManager: 无法找到 Main/SystemMenuLayer 节点")
		return null
	
	var system_menu := system_menu_layer.get_node_or_null("SystemMenu")
	if not system_menu:
		Logging.err("InputManager: 无法找到 Main/SystemMenuLayer/SystemMenu 节点")
		return null
	
	return system_menu
