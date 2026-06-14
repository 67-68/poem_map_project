@tool
extends MeshDataTool
@export var start_ = false:
const Logging = preload("res://core/logger.gd")
	set(val):
		if val:
			start_ = false
			start()
			
var mesh: Mesh

func start():
	create_from_surface(mesh, 0)
	Logging.info("顶点 0 位置:  %s" % [get_vertex(0)])  # 可能为原点
