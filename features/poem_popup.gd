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
	
	# 1. 动画前置：先全部隐藏，防止测量时的闪烁 🤓☝️
	$BookPanel.modulate.a = 0
	
	# 2. 测量阶段
	var sizes = await SizeService.get_size(
		[$BookPanel],
		$BookPanel/MarginContainer/VBoxContainer/TitleLabel,
		$BookPanel/MarginContainer/VBoxContainer/ContentLabel
	)
	var target_width = Util.get_highest_val_from_dict_vec2(sizes, 0)

	# 3. 初始状态重置 (此时是在测量之后)
	$BookPanel/MarginContainer/VBoxContainer/TitleLabel.modulate.a = 0
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.visible_ratio = 0
	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.modulate.a = 0
	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.scale = Vector2(3,3)
	
	# 重要：把宽度压扁，并让面板显现（虽然现在宽度是0）
	$BookPanel.custom_minimum_size.x = 0
	$BookPanel.modulate.a = 1.0 
	
	# 4. 动画启动
	tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 驱动最小宽度！不要动 size！
	tw.tween_property($BookPanel, 'custom_minimum_size:x', target_width, 0.7)

	# --- 后续动画 ---
	tw.parallel().tween_property($BookPanel/MarginContainer/VBoxContainer/TitleLabel,'modulate:a',1.0,0.5)
	tw.tween_property($BookPanel/MarginContainer/VBoxContainer/ContentLabel,'visible_ratio',1.0,0.7)
	
	tw.tween_property($BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp,'modulate:a',1,0.3)
	tw.parallel().tween_property($BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp,'scale',Vector2(1,1),0.3)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_poem.connect(self.on_apply_poem)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
