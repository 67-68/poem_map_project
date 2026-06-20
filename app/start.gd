extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_pressed() -> void:
	var tree := get_tree()
	EventBus.request_start_black.emit(true)
	await tree.create_timer(1.0).timeout
	EventBus.request_start_black.emit(false)
	await tree.create_timer(1.0).timeout
	tree.change_scene_to_file("res://main.tscn")
