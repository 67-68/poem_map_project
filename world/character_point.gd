extends Node2D

var datamodel: PoetData
var path: Curve2D
var time_position_curve: Curve

var previous_color: Color
var emotion_curve: Curve # length_2_float_emotion
var emotion_gradient: Gradient # float_emotion_2_color
var next_point_year: float

var _last_position: Vector2 = Vector2.ZERO
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func setup_emotion():
	emotion_curve = Curve.new()
	var total_len = path.get_baked_length()
	var current_dist = 0.0

	# 遍历每个点
	for i in range(datamodel.path_point_keys.size()):
		var point = Global.life_path_points[datamodel.path_point_keys[i]]
		
		# 计算这个点在路径上的累计距离
		# (Curve2D 有一个好用的函数可以直接算这个)
		current_dist = path.get_closest_offset(point.position)
		var ratio = current_dist / total_len
		
		# 防止浮点数误差导致超过 1.0
		ratio = clamp(ratio, 0.0, 1.0)
		emotion_curve.add_point(Vector2(ratio, point.emotion))

	emotion_gradient = Gradient.new()
	emotion_gradient.remove_point(0)
	emotion_gradient.remove_point(0)

	emotion_gradient.add_point(0,Global.sad_color)
	emotion_gradient.add_point(1,Global.happy_color)
	

func _ready() -> void:
	_last_position = global_position
	anim_sprite.play("idle")

	$Footstep.top_level = true
	if datamodel:
		$Label.text = datamodel.name
		_create_path()
		next_point_year = Global.life_path_points[datamodel.path_point_keys[0]].year

	setup_emotion()

func on_move():
	if $Footstep.get_point_count() > 50:
		$Footstep.remove_point(0)
	$Footstep.add_point(position)

func on_change_emotion_color(current_offset: int):
	var ratio_distance = current_offset / path.get_baked_length()
	var emotion_float = emotion_curve.sample(ratio_distance)
	var emotion_color = emotion_gradient.sample(emotion_float)

	var is_extreme = emotion_float < 0.1 or emotion_float > 0.9
	# Logging.debug('emotion for %s: %s' % [datamodel.name,round(emotion_float * 10)/10])
	#if is_extreme:
		#Global.change_background_color.emit(emotion_color)
		#$EmotionColor.visible = false
		#$EmotionColor.enabled = false
	#else:
		#$EmotionColor.color = emotion_color
		#$EmotionColor.visible = true
		#$EmotionColor.enabled = true

func _process(_delta: float) -> void:
	on_move()
	var target_path_ratio: float = time_position_curve.sample(Global.ratio_time) # 当前路径的比例
	var total_length = path.get_baked_length()
	var current_offset = total_length * target_path_ratio # 当前出发了多远，比如1000,total 5000
	position = path.sample_baked(current_offset)
	on_change_emotion_color(current_offset)
	update_anim()

func update_anim():
	# 1. 计算这一帧的瞬时位移向量
	var movement = global_position - _last_position
	
	# 2. 如果位移长度大于一个极小值（防止浮点数抖动导致原地抽搐）
	if movement.length_squared() > 0.01:
		# 播放走路动画
		if anim_sprite.animation != "walk_normal":
			anim_sprite.play("walk_normal")
			
		# 3. 核心：根据 X 轴的位移正负，直接翻转图片！
		if movement.x > 0.1:
			anim_sprite.flip_h = false # 往右走，不翻转
		elif movement.x < -0.1:
			anim_sprite.flip_h = true  # 往左走，水平翻转
	else:
		# 停下来了，恢复站立
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")
			
	# 4. 更新坐标记忆，供下一帧使用
	_last_position = global_position

func _create_path() -> void:
	"""
	在创建之后被调用的类似init的回调函数
	"""
	path = Curve2D.new()
	time_position_curve = Curve.new()
	for point in datamodel.path_point_keys:
		print(datamodel.path_point_keys)
		path.add_point(Global.life_path_points[point].position)
	var path_ratio: float
	var total_path = path.get_baked_length()
	var time_ratio: float
	for point in datamodel.path_point_keys:
		point = Global.life_path_points[point]
		time_ratio = (point.year - Global.start_year) / Global.time_span
		path_ratio = path.get_closest_offset(point.position) / total_path
		time_position_curve.add_point(Vector2(time_ratio,path_ratio))

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("点到我了！我是：", $Label.text)
		handle_selection(viewport,event,shape_idx)
		Global.current_selected_poet = datamodel
		get_viewport().set_input_as_handled()

func return_preivous_color():
	var tween = create_tween()
	tween.tween_property(self,'modulate',previous_color,3).set_ease(Tween.EASE_OUT)

func handle_selection(viewport,event,shape_idx):
	previous_color = modulate
	var tween = create_tween()
	tween.tween_property(self,'modulate',Color.RED,3).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(3).timeout.connect(return_preivous_color)
	Global.user_clicked.emit(datamodel)