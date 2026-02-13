# ----------------------------------------------------------------
# NavigationService - 逻辑层
# ----------------------------------------------------------------
extends Node

var astar: AStar2D
var prov_2_idx: Dictionary = {} # { "su_zhou": 1 }
var idx_2_prov: Dictionary = {}
var dirty = true

func init():
	if not dirty: return
	dirty = false
	astar = AStar2D.new()
	var color_2_prov := {}
	
	# 预处理颜色字典
	for p_id in Global.base_province:
		var prov = Global.base_province[p_id]
		color_2_prov[prov.color.to_html(false)] = p_id
	
	# 2. 获取邻接数据 (注意：load 需要加上 .get_image())
	var img = load(Global.PROVINCE_INDEX_MAP_PATH).get_image()
	var adjacency_map = AdjacencyManager.get_adjacency_map(img, color_2_prov)
	
	# 3. 注册节点
	var idx = 0
	for uid in Global.base_province:
		var prov = Global.base_province[uid]
		# 警告修复：add_point 的参数顺序是 (id, position)
		astar.add_point(idx, prov.position) 
		prov_2_idx[uid] = idx
		idx_2_prov[idx] = uid
		idx += 1
	
	# 4. 【关键缺失修复】：必须建立连接，AStar 才能工作
	for p_id in adjacency_map:
		var from_idx = prov_2_idx.get(p_id, -1)
		for neighbor_id in adjacency_map[p_id]:
			var to_idx = prov_2_idx.get(neighbor_id, -1)
			if from_idx != -1 and to_idx != -1:
				astar.connect_points(from_idx, to_idx)
		
# 根据省份 ID 获取路径点 ID 序列
func get_index_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	
	var s = prov_2_idx.get(start_id, -1)
	var e = prov_2_idx.get(end_id, -1)
	if s == -1 or e == -1: return []
	# AStar2D 返回的是 PackedInt32Array
	return Array(astar.get_id_path(s, e))

# 辅助：根据索引反查省份 ID
func get_province_id_from_idx(target_idx: int) -> String:
	if dirty: init()
	return idx_2_prov.get(target_idx)

func get_uuid_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	var path = get_index_id_path(start_id,end_id)
	var uuids = []
	for p in path:
		uuids.append(get_province_id_from_idx(p))
	return uuids

func get_prov_id_path(start_id: String, end_id: String) -> Array:
	if dirty: init()
	var path = get_index_id_path(start_id,end_id)
	var provs = []
	for p in path:
		provs.append(Global.base_province[get_province_id_from_idx(p)])
	return provs
