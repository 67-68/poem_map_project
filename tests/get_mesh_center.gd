@tool
extends MeshDataTool
@export var start_ = false:
	set(val):
		if val:
			start_ = false
			start()
			
var mesh: Mesh

func start():
	create_from_surface(mesh, 0)
	print("顶点 0 位置: ", get_vertex(0))  # 可能为原点
