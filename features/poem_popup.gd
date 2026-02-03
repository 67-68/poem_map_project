@tool
extends Control

# --- debug ---
@export var debug_animation_start := false:
	set(value):
		print('waht')
		if is_node_ready():		
			var poem = PoemData.new({})
			debug_animation_start = false
			poem.name = 'test_name'
			poem.description = 'test_description'
			poem.popularity = 50
			on_apply_poem(poem)



func on_apply_poem(data: PoemData):
	print('here')
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.text = data.description
	$BookPanel/MarginContainer/VBoxContainer/TitleLabel.text = data.name
	# 设置texture
	# 设置rarity stamp等级

	$BookPanel.custom_minimum_size = Vector2.ZERO
	$BookPanel.size = Vector2.ZERO
	
	await get_tree().process_frame
	
	var target_size = $BookPanel.size
	$BookPanel.size = Vector2.ZERO
	$BookPanel.custom_minimum_size = Vector2.ZERO

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($BookPanel,'size',target_size,0.5)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_poem.connect(self.on_apply_poem)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
