extends Control

@export var radius := 100.0  # 半径，与父节点保持一致

var emotion_points: Array[Vector2] = []  # 存放算出的 5 个 Vector2 顶点
var center: Vector2  # 中心点坐标

# 严禁写面条代码！雷达图的核心是将情绪 Key 映射到固定的角度
const AXIS_CONFIG = {
    "sorrow":      {"angle": -PI/2, "label": "愁苦"},       # -90度，正上方
    "arrogance":   {"angle": -PI/2 + 2*PI/5, "label": "狂傲"},
    "anger":       {"angle": -PI/2 + 4*PI/5, "label": "愤懑"},
    "tranquility": {"angle": -PI/2 + 6*PI/5, "label": "旷达"},
    "ambition":    {"angle": -PI/2 + 8*PI/5, "label": "野心"}
}

func _ready() -> void:
	center = Vector2(size.x / 2, size.y / 2)
	resized.connect(_on_resized)
	Logging.info("[RadarPainting] _ready: size=%s center=%s visible=%s" % [str(size), str(center), str(visible)])

func _on_resized():
	center = Vector2(size.x / 2, size.y / 2)
	Logging.info("[RadarPainting] _on_resized: new size=%s new center=%s" % [str(size), str(center)])
	queue_redraw()

# 坐标转换函数：根据情绪百分比和角度计算 Vector2 偏移量
func calculate_point(emotion_percent: float, angle: float) -> Vector2:
	var r = emotion_percent * radius  # 根据百分比计算实际半径
	var x = r * cos(angle)
	var y = r * sin(angle)
	return center + Vector2(x, y)

# 更新情绪数据（由父节点调用）
func update_emotion_data(points: Array[Vector2]):
	Logging.info("[RadarPainting] update_emotion_data() called: received %d points, self.size=%s self.visible=%s self.is_visible_in_tree()=%s" % [
		points.size(), str(size), str(visible), str(is_visible_in_tree())
	])
	for i in range(points.size()):
		Logging.info("[RadarPainting] update_emotion_data: point[%d]=%s" % [i, str(points[i])])
	emotion_points = points
	center = Vector2(size.x / 2, size.y / 2)
	Logging.info("[RadarPainting] update_emotion_data: center updated to %s, calling queue_redraw()" % str(center))
	queue_redraw()

func _draw():
	Logging.info("[RadarPainting] _draw() called: emotion_points.size()=%d center=%s size=%s visible=%s" % [
		emotion_points.size(), str(center), str(size), str(visible)
	])
	
	# 先绘制底图刻度轴（灰色）
	var axis_color = Color(0.5, 0.5, 0.5, 0.3)  # 灰色，半透明
	var label_offset = 15  # 标签距离轴末端的偏移量
	var axes_drawn := 0
	
	for emotion_key in AXIS_CONFIG:
		var angle = AXIS_CONFIG[emotion_key]["angle"]
		var end_point = calculate_point(1.0, angle)  # 100% 长度的轴
		draw_line(center, end_point, axis_color, 1.0)
		axes_drawn += 1
		
		# 绘制情绪标签
		var label_pos = end_point + Vector2(cos(angle), sin(angle)) * label_offset
		var font = get_theme_default_font()
		if font:
			var font_size = 12
			var text = AXIS_CONFIG[emotion_key]["label"]
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			# 居中显示标签
			label_pos.x -= text_size.x / 2
			label_pos.y -= text_size.y / 2
			draw_string(font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.7, 0.7, 0.7, 0.8))
		else:
			Logging.err("[RadarPainting] _draw: get_theme_default_font() returned null!")
	
	Logging.info("[RadarPainting] _draw: drawn %d axes" % axes_drawn)
	
	# 绘制情绪多边形（半透明色块）
	if emotion_points.size() == 5:
		Logging.info("[RadarPainting] _draw: drawing polygon with 5 points: %s" % str(emotion_points))
		var polygon_color = Color(0.3, 0.6, 0.9, 0.4)  # 蓝色，半透明
		draw_colored_polygon(emotion_points, polygon_color)
		Logging.info("[RadarPainting] _draw: draw_colored_polygon() done")
	else:
		Logging.err("[RadarPainting] _draw: emotion_points.size()=%d != 5, skipping polygon draw!" % emotion_points.size())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
