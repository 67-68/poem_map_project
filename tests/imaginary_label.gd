extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.imaginary_changed.connect(update_label)

func update_label() -> void:
	text = 'imaginaries: \n'
	var active = ImaginaryComprehender.get_active_concepts()
	if active.is_empty():
		text += '  (none)'
		return
	for concept_key in active:
		var concept = active[concept_key] as ImaginaryConcept
		if not concept:
			continue
		var fragments = ImaginaryComprehender.get_imaginaries_for_concept(concept_key)
		var frag_count = fragments.size() if fragments else 0
