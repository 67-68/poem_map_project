extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.avaialble_decision_change.connect(refresh_decision)

func refresh_decision(decisions: Array) -> void:
	text = "Available decisions: \n- "
	for decision in decisions:
		text += decision.name + "\n- "