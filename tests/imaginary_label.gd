extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.imaginary_changed.connect(update_label)

func update_label() -> void:
	text = 'imaginaries: \n'
	for i_name in Database.imaginaries:
		var i: ImaginaryConcept = Database.imaginaries[i_name]
		if i.basic_imaginaries.size() > 0:
			text += '- %s: %s imas, level %s' % [i.name, i.basic_imaginaries.size(), i.current_level]
			for entry in i.basic_imaginaries:
				var blueprint_id = entry.get("blueprint_id", "")
				var contexts = entry.get("contexts", [])
				text += '\n- blueprint: %s, contexts: %s' % [blueprint_id, str(contexts)]
