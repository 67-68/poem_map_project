# main_page.gd — 入口场景根脚本
# 负责将 PanelContainer 标签 hover 事件绑定到 Line2D 上。
extends PanelContainer

@export var route_line: NodePath
@export var trigger_pc1: NodePath  # PanelContainer "京"
@export var trigger_pc2: NodePath  # PanelContainer2 "隐"
@export var trigger_pc3: NodePath  # PanelContainer3 "律法"


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
