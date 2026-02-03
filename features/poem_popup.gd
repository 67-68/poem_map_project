@tool
extends Control

# --- debug ---
@export var debug_animation_start := false:
	set(value):
		if is_node_ready():		
			var poem = PoemData.new({})
			debug_animation_start = false
			poem.name = 'test_name'
			poem.description = 'test_description'
			poem.popularity = 50
			on_apply_poem(poem)

var tw: Tween

func on_apply_poem(data: PoemData):
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.text = data.description
	$BookPanel/MarginContainer/VBoxContainer/TitleLabel.text = data.name
	# 设置texture
	# 设置rarity stamp等级
	create_animation()

func create_animation():
	if tw: tw.kill()

	var target_width = Util.get_highest_val_from_dict_vec2(await SizeService.get_size($BookPanel/MarginContainer/VBoxContainer/TitleLabel,$BookPanel/MarginContainer/VBoxContainer/ContentLabel),0)
	
	$BookPanel/MarginContainer/VBoxContainer/TitleLabel.modulate.a = 0
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.visible_ratio = 0
	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.modulate.a = 0
	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.scale = Vector2(3,3)

	# --- 卷轴，背景 ---
	tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($BookPanel,'custom_minimum_size:x',target_width,0.7)

	# --- title ---
	tw.tween_property($BookPanel/MarginContainer/VBoxContainer/TitleLabel,'modulate:a',1.0,0.5)
	#tw.parallel().tween_property( # 似乎layout下position没法随便动，所以先不管这个
	
	# --- content ---
	tw.tween_property($BookPanel/MarginContainer/VBoxContainer/ContentLabel,'visible_ratio',1.0,0.7)

	# --- stamp ---
	tw.tween_property($BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp,'modulate:a',1,0.3)
	tw.parallel().tween_property($BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp,'scale',Vector2(1,1),0.3)



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_poem.connect(self.on_apply_poem)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
