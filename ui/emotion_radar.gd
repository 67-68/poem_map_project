extends Control

var radar_visible: bool = true  # 雷达图显示状态
var radar_paint: Control  # 子节点引用
var emotion_label: Label  # 情绪数值显示标签

# 情绪配置 - 与子节点保持一致
const AXIS_CONFIG = {
    "sorrow":      {"angle": -PI/2, "label": "愁苦"},       # -90度，正上方
    "arrogance":   {"angle": -PI/2 + 2*PI/5, "label": "狂傲"},
    "anger":       {"angle": -PI/2 + 4*PI/5, "label": "愤懑"},
    "tranquility": {"angle": -PI/2 + 6*PI/5, "label": "旷达"},
    "ambition":    {"angle": -PI/2 + 8*PI/5, "label": "野心"}
}

const MAX_EMOTION_VALUE = 100  # 情绪最大值，用于计算百分比
const RADIUS = 100.0  # 半径，需要与子节点保持一致

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 延迟一帧，确保子节点已经准备好
	call_deferred("_deferred_ready")

func _deferred_ready():
	# 安全地获取子节点引用
	radar_paint = get_node_or_null("RadarPainting")
	emotion_label = get_node_or_null("Label")
	
	if not radar_paint:
		Logging.err("RadarPainting node not found!")
	
	if not emotion_label:
		Logging.err("Label node not found!")
		return
	
	# 【Fix #1】从场景实际 visible 状态同步，消除双状态脱钩
	radar_visible = visible
	
	# 设置标签颜色为黑色，确保可见
	emotion_label.modulate = Color(0, 0, 0, 1)
	
	# 【核心修复】同时连接旬 tick 和实时情绪变化信号
	TimeService.on_xun_tick.connect(update_emotions)
	if PlayerState.emotion_changed.is_connected(update_emotions):
		PlayerState.emotion_changed.disconnect(update_emotions)
	PlayerState.emotion_changed.connect(update_emotions)
	update_emotions()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			radar_visible = !radar_visible
			visible = radar_visible
			if radar_paint:
				radar_paint.visible = radar_visible
			if emotion_label:
				emotion_label.visible = radar_visible
			Logging.info("Radar visibility toggled: %s" % radar_visible)

# 坐标转换函数：根据情绪百分比和角度计算 Vector2 偏移量
func calculate_point(emotion_percent: float, angle: float, center: Vector2) -> Vector2:
	var r = emotion_percent * RADIUS  # 根据百分比计算实际半径
	var x = r * cos(angle)
	var y = r * sin(angle)
	return center + Vector2(x, y)

func update_emotions():
	if not emotion_label:
		return
	
	# 构建情绪文本显示
	var emotion_text = "情绪状态：\n"
	var has_any_emotion := false
	
	for emotion_key in AXIS_CONFIG:
		var emotion_value = PlayerState.get_emotion(emotion_key)
		var label_text = AXIS_CONFIG[emotion_key]["label"]
		emotion_text += "%s: %d\n" % [label_text, emotion_value]
		if emotion_value > 0:
			has_any_emotion = true
	
	# 【Fix #3】全零情绪时显示兜底提示
	if not has_any_emotion:
		emotion_text = "情绪尚未激活"
	
	emotion_label.text = emotion_text
	
	# 如果雷达绘制节点存在，也更新它
	if radar_paint:
		var points: Array[Vector2] = []
		# 【Fix #2】改用父节点自身 size 而非子节点 size，
		# 避免子节点尚未完成布局时 size=(0,0)
		var center = Vector2(size.x / 2, size.y / 2)
		
		# 遍历 AXIS_CONFIG，计算每个情绪轴的顶点
		for emotion_key in AXIS_CONFIG:
			var angle = AXIS_CONFIG[emotion_key]["angle"]
			var emotion_value = PlayerState.get_emotion(emotion_key)
			
			# 将情绪值转换为百分比 (0.0 - 1.0)
			var emotion_percent = clamp(float(emotion_value) / MAX_EMOTION_VALUE, 0.0, 1.0)
			
			# 计算顶点坐标
			var point = calculate_point(emotion_percent, angle, center)
			points.append(point)
		
		# 将数据传递给子节点进行渲染
		if radar_paint.has_method("update_emotion_data"):
			radar_paint.update_emotion_data(points)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
