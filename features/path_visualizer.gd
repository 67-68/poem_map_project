class_name PathVisualizer extends Node

static func get_bezier_path(p1,p2) -> Curve2D:
	var paths = NavigationService.get_id_path(p1,p2)
	var path_with_noise := Curve2D.new()
	for i in range(paths-1):
		path_with_noise.add_point(get_prov(paths[i]).position)
		path_with_noise.add_point(create_noise(paths[i], paths[i+1]))
		path_with_noise.add_point(get_prov(paths[i+1]).position)
	return path_with_noise

static func get_prov(prov: String) -> Territory:
	return Global.base_province.get(prov)

static func create_noise(p1: String, p2: String):
	var pos = (get_prov(p1).position + get_prov(p2).position) / 2
	pos.x = randi() % Global.PATH_NOISE
	pos.y = randi() % Global.PATH_NOISE
	return pos
