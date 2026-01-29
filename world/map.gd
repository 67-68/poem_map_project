extends Node2D

var datamodel: PoetData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	var poet_repo = DataService_.get_repository(DataService_.Repositories.POET_REPO)

	for item in poet_repo.get_all().values():
		# 初始化点和他们的位置
		var point = character_point.instantiate()
		point.initiate(item)
		var point_repo = DataService_.get_repository(DataService_.Repositories.PATH_POINT_REPO)
		for key in item.path_point_keys:
			point.path_points.append(point_repo.get_by_id(key))
		add_child(point)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

