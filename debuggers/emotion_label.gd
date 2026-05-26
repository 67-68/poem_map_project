extends Label

var base_text = "emotions: \n"

func _process(_delta: float) -> void:
	text = base_text
	for emotion_name in PlayerState.emotions:
		text += "%s: %s\n" % [emotion_name, PlayerState.emotions[emotion_name]]
