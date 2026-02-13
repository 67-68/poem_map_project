class_name Messager extends Path2D

var path_points: Array
var speed_px_per_sec: int
var mesh: MeshInstance2D

func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func initialization(curve_: Curve2D, path_points_: Array, mesh_: MeshInstance2D):
	curve = curve_
	path_points = path_points_
	$MsgPathFollow/TextEmitter.mesh = mesh_
	mesh = mesh
	
func start_travel():
	# 1. 核心 API：获取路径的像素总长度
	# get_baked_length() 是 Godot 预计算好的，性能极高
	var total_distance = curve.get_baked_length()
	
	# 2. 计算出这趟旅程实际需要的秒数
	var travel_duration = total_distance / speed_px_per_sec
	
	# 3. 扔给 Tween 自动执行
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($MsgPathFollow, "progress_ratio", 1.0, travel_duration)
