extends Label

var base_text = '当前可用行动:'

func on_selected_actions_change(actions: Array[Action]):
	text = base_text
	for a in actions:
		text += "\n- " + a.name

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = base_text
	Global.selected_actions_change.connect(on_selected_actions_change)