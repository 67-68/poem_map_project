extends Control

var tw: Tween

@export var stamp_config := preload('res://assets/stamp_config.tres')
@onready var book_panel = $BookPanel
@onready var title_label = $BookPanel/MarginContainer/HBox/VBox/TitleLabel
@onready var content_label = $BookPanel/MarginContainer/HBox/VBox/ContentLabel
@onready var rarity_stamp = $BookPanel/MarginContainer/HBox/RarityStamp

func on_apply_poem(data: PoemData,poet_data):
	position = data.position
	show()

	content_label.text = data.example
	title_label.text = data.name

	#rarity_stamp.texture = stamp_config.get_config(data.get_scarcity()).texture
	#rarity_stamp.modulate = stamp_config.get_config(data.get_scarcity()).color
	
	if data.background == PoemData.Poem_BG.BOOK:
		pass

	var juanzhou_bg = preload('res://assets/poem_background_juanzhou.tres')
	book_panel.add_theme_stylebox_override('panel',juanzhou_bg)
	create_animation()
	create_notification(data,poet_data)

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
	content_label.visible_ratio = 0
	title_label.modulate.a = 0
	rarity_stamp.modulate.a = 0
	rarity_stamp.scale = Vector2(3,3)

	
	# 重要：把宽度压扁，并让面板显现（虽然现在宽度是0）
	book_panel.custom_minimum_size.x = 0
	book_panel.modulate.a = 1.0 
	
	# 4. 动画启动
	tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 驱动最小宽度！不要动 size！
	tw.tween_property(book_panel, 'custom_minimum_size:x', target_width, 2.0)

	await tw.finished
	content_label.custom_minimum_size = sizes[
		content_label
	]
	rarity_stamp.custom_minimum_size = Vector2(sizes[book_panel][1],sizes[book_panel][1])

	# --- 后续动画 ---
	tw = create_tween()
	await get_tree().process_frame
	tw.tween_property(title_label,'modulate:a',1.0,0.9)
	tw.tween_property(content_label,'visible_ratio',1.0,1.5)
	
	tw.tween_property(rarity_stamp,'modulate:a',1,0.5)
	tw.tween_property(rarity_stamp,'scale',Vector2(1,1),0.7)
	
	await tw.finished
	AudioManager.play_sfx(preload("res://assets/sounds/stamp_sound.wav"))

	end_animation()
	

func create_notification(poem_data: PoemData, poet_data: PoetData):
	#var poet = poet_data.get_rich_poet()
	#var poem = poem_data.get_rich_poem()
	#var pop = poem_data.get_scarcity()
	#var popularity_str = poem_data.get_scarcity_str(pop)
	#var popularity = Util.colorize_underlined_link(popularity_str,stamp_config.get_config(pop).color,popularity_str)
	#EventBus.request_text_popup.emit('%s 在 %d 年创作了 %s, 稀有度为 %s' % [poet,GameState.year,poem,popularity])
	pass

func end_animation():
	SizeService.minimize_all([rarity_stamp,content_label,title_label])
	hide()
	EventBus.poem_animation_finished.emit()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.request_apply_poem.connect(self.on_apply_poem)
