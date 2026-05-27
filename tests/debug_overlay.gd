# DebugOverlay.gd
@tool
extends Control

var connections_data: Dictionary = {}
var centers_data: Dictionary = {}

func _draw():
	z_index = 5
	# 只有在这里，draw_line 才是合法的！
	if connections_data.is_empty() or centers_data.is_empty():
		return
		
	# 这里调用你的工具类，把 'self' 传进去作为 canvas_item
	DebugUtils.draw_debug_connections(self, connections_data, centers_data)

# 用于外部更新数据并请求重绘
func update_debug_info(conn: Dictionary, centers: Dictionary):
	connections_data = conn
	centers_data = centers
	queue_redraw() # 告诉引擎：“下一帧到了绘图环节记得叫我”