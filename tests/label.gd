extends Label

var base_text = 'props: \n'

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = 'props: \n'


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = base_text
	for s in PlayerState.stats:
		text += "%s: %s\n" % [s, PlayerState.stats[s]]
