extends Node2D

var datamodel: PoetData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	var poet_repo = DataService_.get_repository(PoetData)
	var path_repo = DataService_.get_repository(PoetLifePoint)

	for item in poet_repo.get_all():
		add_child(character_point.instantiate().initiate(item,path_repo))
		var vec = Vector2(item.path_points[0].position[0], item.path_points[0].position[1])		
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

