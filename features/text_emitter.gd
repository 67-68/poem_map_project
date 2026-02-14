class_name TextEmitter extends Node2D

var _last_prov_id := ""
var mesh: MeshInstance2D

func _ready():
	pass

func _process(_delta):
	_detect_and_emit()

func _detect_and_emit():
	if not mesh or not Global.index_image:
		return

	# 1. 获取相对于 Mesh 节点的局部坐标
	var local_pos = mesh.to_local(global_position)
	
	# 2. 获取 Mesh 的 AABB (轴对齐包围盒)
	# 注意：对于 ArrayMesh，get_aabb() 通常是准确的
	var aabb = mesh.mesh.get_aabb()
	var mesh_size = Vector2(aabb.size.x, aabb.size.y)
	
	# 4. 关键修正：处理原点偏移 (UV 映射)
	# 假设 Mesh 的原点在中心 (0,0)，那么左上角就是 -mesh_size / 2
	# 我们需要把 local_pos 转换到 [0, mesh_size] 的范围内
	var offset_pos = local_pos + (mesh_size / 2.0)
	
	# 5. 计算 UV
	var uv = offset_pos / mesh_size
	
	# --- 调试日志 (可选) ---
	# print("Local: ", local_pos, " Offset: ", offset_pos, " Size: ", mesh_size, " UV: ", uv)

	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: 
		Logging.err('text emitter is outside of the map!!!')
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
