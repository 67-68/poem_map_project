extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.imaginary_changed.connect(update_label)

func update_label():
	text = 'imaginaries: \n'
	for i_name in Database.imaginaries:
		var i = Database.imaginaries.get(i_name)
		if i.basic_imaginaries:
			text += '- %s: %s imas, level %s' % [i.name, i.basic_imaginaries.size(), i.current_level]
			for entry in i.basic_imaginaries:
				var blueprint_id = entry.get("blueprint_id", "")
				var contexts = entry.get("contexts", [])
				text += '\n- blueprint: %s, contexts: %s' % [blueprint_id, str(contexts)]
