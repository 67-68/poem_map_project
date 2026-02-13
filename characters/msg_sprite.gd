extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta):
	# 打印身世之谜
	print("Sprite Global: ", global_position, " | Parent Global: ", get_parent().global_position)
	print("Top Level?: ", top_level)
	print("Visible?: ", visible)
	print("Texture Size: ", texture.get_size() if texture else "NULL TEXTURE")

	
