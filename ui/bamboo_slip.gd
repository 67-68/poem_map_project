extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

@onready var btn = $VBoxContainer/TextureButton
@onready var chain = $VBoxContainer/TextureButton/TextureRect

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func apply_relation(name: String):
	$VBoxContainer/Label.text = name

func apply_state(state: String):
	match state:
		"HATE": 
			chain.visible = true
			btn.disabled = true
		"HEARD":
			chain.visible = false
			btn.disabled = true
		"GOOD":
			chain.visible = false
			btn.disabled = false
		"CORE":
			chain.visible = false
			btn.disabled = false
		_: Logging.err('bamboo slip: what the hell is this state %s' % state)
