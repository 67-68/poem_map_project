# main_page.gd — 入口场景根脚本
# 负责将 PanelContainer 标签 hover 事件绑定到 Line2D 上，以及点击逻辑。
extends PanelContainer

@export var route_line: NodePath
@export var trigger_pc1: NodePath  # PanelContainer tr("UI_MAIN_PAGE_TEXT_0") (Start)
@export var trigger_pc2: NodePath  # PanelContainer2 tr("UI_MAIN_PAGE_TEXT_1") (Quit)
@export var trigger_pc3: NodePath  # PanelContainer3 tr("UI_MAIN_PAGE_TEXT_2") (Settings)


func _ready() -> void:
	var line: Node = get_node_or_null(route_line)
	if not line:
		Logging.err("main_page: route_line 未设置")
		return

	var t1: Control = get_node_or_null(trigger_pc1) as Control
	var t2: Control = get_node_or_null(trigger_pc2) as Control
	var t3: Control = get_node_or_null(trigger_pc3) as Control

	# 把三组 trigger + 坐标注入 Line2D
	if line.has_method("bind_triggers"):
		line.bind_triggers([
			[t1, Vector2(665, 240), Vector2(560, 310)],  # 京
			[t2, Vector2(665, 240), Vector2(686, 365)],  # 隐
			[t3, Vector2(665, 240), Vector2(835, 38)],   # 律法
		])
		Logging.info("main_page: 已绑定 3 个 trigger 到 route_line")
	else:
		Logging.err("main_page: route_line 缺少 bind_triggers 方法")

	# ── 连接点击逻辑 ──
	if t1:
		t1.gui_input.connect(_on_start_clicked)
		Logging.info("main_page: 已连接 Start.gui_input")
	else:
		Logging.err("main_page: Start PanelContainer 为 null")

	if t2:
		t2.gui_input.connect(_on_quit_clicked)
		Logging.info("main_page: 已连接 Quit.gui_input")
	else:
		Logging.err("main_page: Quit PanelContainer 为 null")

	if t3:
		t3.gui_input.connect(_on_settings_clicked)
		Logging.info("main_page: 已连接 Settings.gui_input")
	else:
		Logging.err("main_page: Settings PanelContainer 为 null")


# ── 点击回调 ─────────────────────────────────────────────

## 开始游戏：黑屏过渡 → main.tscn
func _on_start_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	Logging.info("main_page: Start 被点击，即将转换到 main.tscn")
	var tree := get_tree()
	# 复用 app/start.gd 的过渡协议：先黑屏再亮屏再切场景
	EventBus.request_start_black.emit(true)
	await tree.create_timer(1.0).timeout
	EventBus.request_start_black.emit(false)
	await tree.create_timer(1.0).timeout
	tree.change_scene_to_file("res://main.tscn")


## 退出游戏
func _on_quit_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	Logging.info("main_page: Quit 被点击，退出游戏")
	get_tree().quit()


## 设置（律法）：当前 main_page 场景无系统菜单，仅打日志
func _on_settings_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	Logging.info("main_page: Settings 被点击（暂无可用操作，main_page 场景下系统菜单不可用）")
