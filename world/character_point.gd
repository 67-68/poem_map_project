extends Node2D

var datamodel: PoetData
var path: Curve2D
var previous_color: Color

func _ready() -> void:
	if datamodel:
		$Label.text = datamodel.name
		_create_path()

func _process(delta: float) -> void:
	var total_length = path.get_baked_length()
	var current_offset = total_length * Global.ratio_time
	position = path.sample_baked(current_offset)
	

func _create_path() -> void:
	"""
	在创建之后被调用的类似init的回调函数
	"""
	path = Curve2D.new()
	for point in datamodel.path_points:
		path.add_point(point)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("点到我了！我是：", $Label.text)
		handle_selection(viewport,event,shape_idx)
		get_viewport().set_input_as_handled()

func handle_selection(viewport,event,shape_idx):
	previous_color = modulate
	modulate = Color.RED
	Global.poet_clicked.emit(datamodel)