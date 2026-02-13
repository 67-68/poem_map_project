class_name TextEmitter extends Node2D

var _last_prov_id := ""
var mesh: MeshInstance2D

func _ready():
	pass

func _process(_delta):
	_detect_and_emit()

func _detect_and_emit():
	var local_pos = mesh.to_local(global_position) # 获取text emiiter的本地坐标，相对于mesh来说

	var mesh_size = mesh.get_rect().size # 获取mesh的大小

	var uv = local_pos/mesh_size # 归一化

	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: 
		Logging.err('text emitter position is out of the mesh %s' % uv)
		Logging.err('mesh_size '+mesh_size)
		Logging.err('local_pos '+local_pos)
		return
	
	var px = int(uv.x * Global.index_image.get_width())
	var py = int(uv.y * Global.index_image.get_height())

	var color = Global.index_image.get_pixel(px, py)
	if color.a < 0.1: return # 在水里或荒野

	var hex = color.to_html(false)
	var current_province_id = Global.color_2_province.get(hex, "")
	if current_province_id != _last_prov_id and current_province_id != "":
		_emit_text(current_province_id)
		_last_prov_id = current_province_id

func _emit_text(prov_id):
	var prov_name = Global.base_province[prov_id].name
	print("进入了：", prov_name)

# ankize: 获取mesh大小的方法
