extends Node2D

var datamodel: PoetData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	for item in Global.poet_data.values():
		var node = character_point.instantiate()
		var vec = Vector2(Global.life_path_points[item.path_point_keys[0]].position)
		var color = item.color
		node.modulate = color
		node.position = vec
		node.get_node('Label').text = item.name
		node.datamodel = item

		add_child(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

