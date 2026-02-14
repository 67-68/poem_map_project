class_name Messager extends Path2D

var path_points: Array
var speed_px_per_sec: int
var txt: String
var mesh: MeshInstance2D
var allow_timer := false

signal travel_end()

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if $TrailLine.get_point_count() > 50:
		$TrailLine.remove_point(0)
	$TrailLine.add_point($MsgPathFollow.position)

func initialization(curve_: Curve2D, path_points_: Array, mesh_: MeshInstance2D):
	Logging.exists('init of messager',curve_,path_points_,mesh_)
	curve = curve_
	path_points = path_points_
	$MsgPathFollow/TextEmitter.mesh = mesh_
	mesh = mesh_
	Logging.info('passanger: mesh设置完成 %s' % mesh)
	
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
