extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

@onready var btn = $VBoxContainer/TextureButton
@onready var chain = $VBoxContainer/TextureButton/TextureRect
@export var trait_uuid = ''

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func apply_relation(name: String, trait_uuid_: String):
	$VBoxContainer/Label.text = name
	trait_uuid = trait_uuid_

func apply_state(state: String):
	#breakpoint
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


func _on_texture_button_pressed() -> void:
	var context = {'main_tag': trait_uuid}
	EventManager.scan_events(0.0, context)
