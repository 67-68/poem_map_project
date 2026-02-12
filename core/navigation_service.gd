class_name NavigationService extends RefCounted
var astar: AStar2D

func _ready():
	astar = AStar2D.new()
	for uid in Global.base_province:
		var prov = Global.base_province[uid] as Territory
		astar.add_point