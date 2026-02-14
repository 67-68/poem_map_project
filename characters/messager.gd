class_name Messager extends Path2D

var path_points: Array
var speed_px_per_sec: int
var txt: String
var mesh: MeshInstance2D
var allow_timer := false

signal travel_end()
func _process(_delta: float) -> void:
	# --- 过去的拖尾 (CPU 维护) ---
	if $TrailLine.get_point_count() > 150:
		$TrailLine.remove_point(0)
	$TrailLine.add_point($MsgPathFollow.position)
	
	# --- 未来的路径 (GPU 同步) ---
	# 核心：利用 PathFollow2D 自带的 progress_ratio (0.0 到 1.0)
	# 将其作为一个匀速递增的浮点数，直接塞进 Shader 的嘴里
	var future_mat = $FutureLine.material as ShaderMaterial
	if future_mat:
		future_mat.set_shader_parameter("current_progress", $MsgPathFollow.progress_ratio)

func initialization(curve_: Curve2D, path_points_: Array, mesh_: MeshInstance2D):
	Logging.exists('init of messager', curve_, path_points_, mesh_)
	curve = curve_
	
	# 😡 那个传进来的 path_points_ 已经是历史的垃圾了，以后可以把它从接口里删掉
	# path_points = path_points_ 
	
	$MsgPathFollow/TextEmitter.mesh = mesh_
	mesh = mesh_
	Logging.info('passanger: mesh设置完成 %s' % mesh)

	# -----------------------------------------------------
	# 核心基建：初始化 Future Line
	# -----------------------------------------------------
	var future_line = $FutureLine as Line2D
	
	# 防御性编程 1：强制接管 UV 展开，防止你在编辑器里忘记设为 Stretch 💀
	future_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	
	# 防御性编程 2：拿来主义，直接把引擎在 C++ 层算好的平滑曲线点塞进去
	# get_baked_points() 会返回一条密度极高、绝对贴合的完美曲线
	future_line.points = curve.get_baked_points()

	
func start_travel():
	# 1. 核心 API：获取路径的像素总长度
	# get_baked_length() 是 Godot 预计算好的，性能极高
	var total_distance = curve.get_baked_length()
	print("🐎 信使出发！位置: ", global_position, " 路径长度: ", curve.get_baked_length())
	
	# 2. 计算出这趟旅程实际需要的秒数
	var travel_duration = total_distance / speed_px_per_sec
	
	# 3. 扔给 Tween 自动执行
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($MsgPathFollow, "progress_ratio", 1.0, travel_duration)
	tween.tween_callback(end_timer)
	allow_timer = true
	start_timer()
	

func start_timer():
	if allow_timer:
		#breakpoint
		TextPoolManager.spawn(txt,$MsgPathFollow.global_position)
		print($MsgPathFollow.global_position)
		var timer = get_tree().create_timer(randi() % 5)
		timer.timeout.connect(start_timer)

func end_timer():
	allow_timer = false
	travel_end.emit()
