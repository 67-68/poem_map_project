extends RefCounted
var astar: AStar2D
var prov_2_idx: Dictionary[String, int] = {}
var adjacency_map := {}

func _ready():
	var color_2_prov := {}
	for p in Global.base_province:
		var prov = Global.base_province[p]
		color_2_prov[prov.color] = prov.uuid
	adjacency_map = AdjacencyManager.get_adjacency_map(load(Global.PROVINCE_INDEX_MAP_PATH),color_2_prov)
	var idx = 0
	astar = AStar2D.new()
	for uid in Global.base_province:
		var prov = Global.base_province[uid] as Territory
		astar.add_point(prov.position,idx)
		prov_2_idx[prov.uuid] = idx
		idx += 1

func get_id_path(start,end):
	return astar.get_id_path(start,end)