class_name TombstoneScreen extends CanvasLayer

const FinalPoemLabelScene: PackedScene = preload("res://ui/final_poem_label.tscn")

@onready var portrait_rect: TextureRect = $ColorRect/M/H/M/Portrait
@onready var monolith_text: RichTextLabel = $ColorRect/M/H/S/MonolithText
@onready var sub_viewport: SubViewport = $ColorRect/M/H/V/PanelContainer/S/V/SubViewportContainer/SubViewport

func _ready():
	Logging.info('TombstoneScreen._ready: entering as standalone scene root, reading death_reason/death_tutorial from GameState')
	render_entropy_death()
	EventBus.request_return_to_main_menu.connect(_on_return_to_main_menu)
	Logging.info('TombstoneScreen._ready: connected to request_return_to_main_menu signal')

## 核心接口：接收死因与评语，拼装历史巨石碑
func render_entropy_death() -> void:
	var reason: String = tr(GameState.death_reason)
	var judgement: String = tr(GameState.death_tutorial)
	var time_action_rank = PlayerObserver.get_time_action_rank()
	if GameState.drained_resource_type:
		var specific_resource = PlayerObserver.get_specific_resource(GameState.drained_resource_type)
		#TODO: assign to label
	var midware_proudct = PlayerObserver.get_midware_product()
	var history = PlayerObserver.get_player_history()
	_populate_poems()
	var poem_accessment #同样从player observer get

## 从 PlayerState.created_poems 获取诗词列表，随机铺排到 SubViewport 中
func _populate_poems() -> void:
	Logging.info('TombstoneScreen._populate_poems: start')
	
	# 清空 SubViewport 现有子节点（包括 placeholder label）
	for child in sub_viewport.get_children():
		child.queue_free()
	Logging.info('TombstoneScreen._populate_poems: cleared %d existing children' % sub_viewport.get_child_count())
	
	var poems: Array = PlayerState.created_poems
	if poems.is_empty():
		Logging.info('TombstoneScreen._populate_poems: PlayerState.created_poems is empty, nothing to render')
		return
	
	Logging.info('TombstoneScreen._populate_poems: got %d poems from PlayerState.created_poems' % poems.size())
	
	var viewport_size: Vector2 = sub_viewport.size
	Logging.info('TombstoneScreen._populate_poems: viewport size = %s' % str(viewport_size))
	
	var idx: int = 0
	for poem in poems:
		if not poem is Poem:
			Logging.info('TombstoneScreen._populate_poems: idx=%d is not a Poem (%s), skipping' % [idx, poem.get_class() if poem else "null"])
			idx += 1
			continue
		
		if poem.name.is_empty():
			Logging.info('TombstoneScreen._populate_poems: idx=%d Poem has empty name, skipping' % idx)
			idx += 1
			continue
		
		var label: RichTextLabel = FinalPoemLabelScene.instantiate()
		if not label:
			Logging.err('TombstoneScreen._populate_poems: idx=%d failed to instantiate final_poem_label.tscn' % idx)
			idx += 1
			continue
		
		label.text = poem.name
		Logging.info('TombstoneScreen._populate_poems: idx=%d poem.name=%s' % [idx, poem.name])
		
		# 随机放置：约束在 viewport 边界内
		# 先给一个默认尺寸估算，实际尺寸在 yield 后可用；用固定 240×30 做约束
		var label_w: float = label.size.x if label.size.x > 0 else 240.0
		var label_h: float = label.size.y if label.size.y > 0 else 30.0
		var max_x: float = max(viewport_size.x - label_w, 0.0)
		var max_y: float = max(viewport_size.y - label_h, 0.0)
		
		label.position = Vector2(randf_range(0.0, max_x), randf_range(0.0, max_y))
		Logging.info('TombstoneScreen._populate_poems: idx=%d position=%s' % [idx, str(label.position)])
		
		# 随机染色：RGB 随机 + alpha 在 0.70~0.95 之间
		label.self_modulate = Color(randf(), randf(), randf(), randf_range(0.70, 0.95))
		Logging.info('TombstoneScreen._populate_poems: idx=%d self_modulate=%s' % [idx, str(label.self_modulate)])
		
		sub_viewport.add_child(label)
		Logging.info('TombstoneScreen._populate_poems: idx=%d added to sub_viewport' % idx)
		idx += 1
	
	Logging.info('TombstoneScreen._populate_poems: done, %d labels added' % sub_viewport.get_child_count())

func _on_button_pressed() -> void:
	Logging.info('TombstoneScreen: exit button pressed, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_return_to_main_menu() -> void:
	Logging.info('TombstoneScreen: return_to_main_menu signal received, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")
