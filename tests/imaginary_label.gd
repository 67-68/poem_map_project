extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.imaginary_changed.connect(update_label)

func update_label():
	text = 'imaginaries: \n'
	for i_name in Global.imaginaries:
		var i = Global.imaginaries.get(i_name)
		if i.basic_imaginaries:
			text += '- %s: %s imas, level %s' % [i.name, i.basic_imaginaries.size(), i.current_level]
			for bi in i.basic_imaginaries:
				text += '\n- ' + bi
