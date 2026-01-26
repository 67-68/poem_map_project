extends Node2D

var datamodel: PoetData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var character_point = load("res://world/character_point.tscn")
	var char_data = DataLoader.load_json_file("res://data/poet_data.json","res://data/path_points.json")
	for item in char_data:
		var node = character_point.instantiate()
		var vec = Vector2(item.path_points[0].position[0], item.path_points[0].position[1])
		var color = item.color
		node.modulate = color
		node.position = vec
		node.get_node('Label').text = item.title
		node.datamodel = item

		add_child(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var color = lerp(Global.sad_color,Global.happy_color,0.5)
	$background.modulate = color

