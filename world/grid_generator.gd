@tool
extends MeshInstance2D

@export var generate_grid: bool = false : set = _set_generate_grid
@export var size: Vector2 = Vector2(1000, 1000)
@export var subdivide: int = 100

func _set_generate_grid(_val):
	if not _val: return
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 1. 生成顶点数据 (Vertices & UVs)
	# 需要 (subdivide + 1) 个点来围成 subdivide 个格子
	for y in range(subdivide + 1):
		for x in range(subdivide + 1):
			var uv = Vector2(float(x) / subdivide, float(y) / subdivide)
			st.set_uv(uv)
			# 这里我们将顶点展开在 2D 平面上
			st.add_vertex(Vector3(uv.x * size.x, uv.y * size.y, 0))
	
	# 2. 生成索引数据 (Indices)
	# 每一个格子 (Quad) 产生 2 个三角形，共 6 个索引
	for y in range(subdivide):
		for x in range(subdivide):
			# 计算当前格子左上角顶点的索引
			var top_left = y * (subdivide + 1) + x
			var top_right = top_left + 1
			var bottom_left = (y + 1) * (subdivide + 1) + x
			var bottom_right = bottom_left + 1
			
			# 第一个三角形 (Top-Left, Top-Right, Bottom-Left)
			st.add_index(top_left)
			st.add_index(top_right)
			st.add_index(bottom_left)
			
			# 第二个三角形 (Top-Right, Bottom-Right, Bottom-Left)
			st.add_index(top_right)
			st.add_index(bottom_right)
			st.add_index(bottom_left)
			
	mesh = st.commit()
	print("🤓☝️ 架构师：大唐地理网格已精准生成。三角形总数: ", subdivide * subdivide * 2)