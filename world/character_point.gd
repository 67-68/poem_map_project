extends Node2D

var datamodel: PoetData
var path: Curve2D
var time_position_curve: Curve
var path_points: Array[PoetLifePoint] = []

var previous_color: Color
var emotion_curve: Curve # length_2_float_emotion
var emotion_gradient: Gradient # float_emotion_2_color

func setup_emotion():
	emotion_curve = Curve.new()
	var total_len = path.get_baked_length()
	var current_dist = 0.0

	# 遍历每个点
	for i in range(path_points.size()):
		var point = path_points[i]
		
		# 计算这个点在路径上的累计距离
		# (Curve2D 有一个好用的函数可以直接算这个)
		current_dist = path.get_closest_offset(point.position)
		
		var ratio = current_dist / total_len
		
		# 防止浮点数误差导致超过 1.0
		ratio = clamp(ratio, 0.0, 1.0)
		
		emotion_curve.add_point(Vector2(ratio, point.emotion))

	emotion_gradient = Gradient.new()
	emotion_gradient.set_color(0, Global.sad_color)
	emotion_gradient.set_color(1, Global.happy_color)
	

func _ready() -> void:
	$Footstep.top_level = true
	if datamodel:
		$Label.text = datamodel.name
		_create_path()

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
	# Logging.debug('emotion for %s: %s' % [datamodel.title,round(emotion_float * 10)/10])
	if is_extreme:
		Global.change_background_color.emit(emotion_color)
		$EmotionColor.visible = false
		$EmotionColor.enabled = false
	else:
		$EmotionColor.color = emotion_color
		$EmotionColor.visible = true
		$EmotionColor.enabled = true


func _process(delta: float) -> void:
	on_move()

	var target_path_ratio: float = time_position_curve.sample(Global.ratio_time) # 当前路径的比例

	var total_length = path.get_baked_length()
	var current_offset = total_length * target_path_ratio # 当前出发了多远，比如1000,total 5000
	position = path.sample_baked(current_offset)
	on_change_emotion_color(current_offset)
	

func _create_path() -> void:
	"""
	在创建之后被调用的类似init的回调函数
	"""
	path = Curve2D.new()
	time_position_curve = Curve.new()
	for point in path_points:
		path.add_point(point.position)

	var path_ratio: float
	var total_path = path.get_baked_length()
	var time_ratio: float
	for point in path_points:
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

func initiate(data: PoetData):
	modulate = data.color
	datamodel = data
	var repo = DataService_.get_repository(DataService_.Repositories.POET_REPO)
	var life_point_uuid = repo.get_item_cache(PoetLifePoint,datamodel.uuid)

	position = Vector2(DataService_.resolve_uuid(PoetLifePoint,life_point_uuid[0]).position)
	get_node('Label').text = data.name
	

	return self