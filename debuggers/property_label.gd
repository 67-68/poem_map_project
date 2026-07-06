extends Label

var base_text = 'props: \n'

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = 'props: \n'


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not Database:
		Logging.err("property_label: Database autoload not ready in _process, skipping frame")
		return
	text = base_text
	for s in Database.get_properties_all():
		text += "%s: %s\n" % [s, PlayerState.get_stat_val(s)]
		text += 'stage-percep: %s\n' % Database.get_property(s).get_staged_perception_text()
