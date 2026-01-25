extends Node2D

var datamodel: PoetData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	var char_data = DataLoader.load_json_file("res://data/characters.json")
	for item in char_data:
		var node = character_point.instantiate()
		var vec = Vector2(item.path_points[0][0], item.path_points[0][1])
		var color = item.color
		node.modulate = color
		node.position = vec
		node.get_node('Label').text = item.name
		node.datamodel = item

		add_child(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
