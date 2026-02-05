@tool
extends Control

@export var stamp_config := preload('res://features/stamp_config.tres')
var tw: Tween

func on_apply_poem(data: PoemData):
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.text = data.description
	$BookPanel/MarginContainer/VBoxContainer/TitleLabel.text = data.name
	# 设置texture

	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.texture = stamp_config.get_config(data.get_scarcity()).texture
	$BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp.modulate = stamp_config.get_config(data.get_scarcity()).color

	if data.background == PoemData.Poem_BG.BOOK:
		pass


	var juanzhou_bg = preload('res://features/poem_background_juanzhou.tres')
	$BookPanel.add_theme_stylebox_override('panel',juanzhou_bg)

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
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.custom_minimum_size = sizes[
		$BookPanel/MarginContainer/VBoxContainer/ContentLabel
	]
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
	
	await tw.finished
	$PoemAnimation/StampPlayer.play()

func end_animation():
	$BookPanel/MarginContainer/VBoxContainer/ContentLabel.fit_content = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_poem.connect(self.on_apply_poem)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
