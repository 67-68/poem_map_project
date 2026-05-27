extends Label

var base_text = 'props: \n'

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = 'props: \n'


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = base_text
	for s in Database.properties:
		text += "%s: %s\n" % [s, Database.properties[s].val]
		text += 'stage-percep: %s\n' % Database.properties[s].get_staged_perception_text()
