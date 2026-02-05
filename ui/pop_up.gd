extends PanelContainer
	
func on_text_popup(text: String):
	$Con/TextLabel.text = text
	show()
	await get_tree().create_timer(3.0).timeout.connect(hide)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_text_popup.connect(on_text_popup)	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
