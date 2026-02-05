@tool
extends Control

@export var stamp_config := preload('res://features/stamp_config.tres')
var tw: Tween
@onready var book_panel = $BookPanel
@onready var title_label = $BookPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var content_label = $BookPanel/MarginContainer/VBoxContainer/ContentLabel
@onready var rarity_stamp = $BookPanel/MarginContainer/VBoxContainer/StampAnchor/RarityStamp
@onready var stamp_player = $PoemAnimation/StampPlayer

func on_apply_poem(data: PoemData):
	content_label.text = data.description
	title_label.text = data.name
	# 设置texture

	rarity_stamp.texture = stamp_config.get_config(data.get_scarcity()).texture
	rarity_stamp.modulate = stamp_config.get_config(data.get_scarcity()).color

	if data.background == PoemData.Poem_BG.BOOK:
		pass


	var juanzhou_bg = preload('res://features/poem_background_juanzhou.tres')
	book_panel.add_theme_stylebox_override('panel',juanzhou_bg)

	create_animation()

func create_animation():
	if tw: tw.kill()
	
	# 1. 动画前置：先全部隐藏，防止测量时的闪烁 🤓☝️
	book_panel.modulate.a = 0
	
	# 2. 测量阶段
	var sizes = await SizeService.get_size(
		[book_panel],
		title_label,
		content_label
	)
	var target_width = Util.get_highest_val_from_dict_vec2(sizes, 0)

	# 3. 初始状态重置 (此时是在测量之后)
	content_label.custom_minimum_size = sizes[
		content_label
	]
	title_label.modulate.a = 0
	content_label.visible_ratio = 0
	rarity_stamp.modulate.a = 0
	rarity_stamp.scale = Vector2(3,3)
	
	# 重要：把宽度压扁，并让面板显现（虽然现在宽度是0）
	book_panel.custom_minimum_size.x = 0
	book_panel.modulate.a = 1.0 
	
	# 4. 动画启动
	tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 驱动最小宽度！不要动 size！
	tw.tween_property(book_panel, 'custom_minimum_size:x', target_width, 0.7)

	# --- 后续动画 ---
	tw.parallel().tween_property(title_label,'modulate:a',1.0,0.5)
	tw.tween_property(content_label,'visible_ratio',1.0,0.7)
	
	tw.tween_property(rarity_stamp,'modulate:a',1,0.3)
	tw.parallel().tween_property(rarity_stamp,'scale',Vector2(1,1),0.3)
	
	await tw.finished
	stamp_player.play()

func end_animation():
	content_label.fit_content = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.request_apply_poem.connect(self.on_apply_poem)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass