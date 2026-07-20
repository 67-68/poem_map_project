class_name TombstoneScreen extends CanvasLayer

@onready var portrait_rect: TextureRect = $ColorRect/M/H/M/Portrait
@onready var monolith_text: RichTextLabel = $ColorRect/M/H/S/MonolithText

func _ready():
	Logging.info('TombstoneScreen._ready: entering as standalone scene root, reading death_reason/death_tutorial from GameState')
	
	var reason: String = GameState.death_reason
	if reason.is_empty():
		Logging.warn('TombstoneScreen._ready: GameState.death_reason is empty, falling back to death_cause')
		reason = GameState.death_cause
		if reason.is_empty():
			Logging.err('TombstoneScreen._ready: both death_reason and death_cause are empty, using fallback')
			reason = tr("CODE_TOMB_STONE_SCREEN_46432180C4")
	
	var tutorial: String = GameState.death_tutorial
	if tutorial.is_empty():
		Logging.info('TombstoneScreen._ready: death_tutorial is empty, skipping tutorial section')
	
	render_entropy_death(reason, tutorial)
	EventBus.request_return_to_main_menu.connect(_on_return_to_main_menu)
	Logging.info('TombstoneScreen._ready: connected to request_return_to_main_menu signal')


## 核心接口：接收死因与评语，拼装历史巨石碑
func render_entropy_death(reason_text: String, tutorial_text: String) -> void:
	Logging.info('TombstoneScreen.render_entropy_death: reason="%s" tutorial="%s"' % [reason_text, tutorial_text])
	
	var bbcode: String = ""
	
	# 【头部：终局宣判】 红色，居中，冷酷无情
	bbcode += tr("CODE_TOMB_STONE_SCREEN_1E45D99EA5")
	bbcode += "[center][color=#aaaaaa]%s[/color][/center]\n\n" % tr(reason_text)
	
	# 【评语：死亡总结】 DeathEvent.death_tutorial — 灰色小字，居中
	if not tutorial_text.is_empty():
		bbcode += "[center][font_size=16][color=#888888]%s[/color][/font_size][/center]\n\n" % tr(tutorial_text)
	
	# 【左上角：风化的世俗属性】 极低透明度的灰色（#88888855），代表无人在意 💀
	bbcode += tr("CODE_TOMB_STONE_SCREEN_2B1EDECF08") % [
		PlayerState.get_stat_val(ENUMS.PROPS.MONEY),
		PlayerState.get_stat_val(ENUMS.PROPS.PROGRESS)
	]
	
	# 【中部：平庸的历史长河】
	#breakpoint
	if not TimeService.get_master_timeline():
		bbcode += tr("CODE_TOMB_STONE_SCREEN_D75D9088E0")
	else:
		bbcode += tr("CODE_TOMB_STONE_SCREEN_E888517B9E")
		for evt in TimeService.get_master_timeline():
			bbcode += tr("CODE_TOMB_STONE_SCREEN_1F46FB6E91") % [evt.time, evt.name]
			
		bbcode += tr("CODE_TOMB_STONE_SCREEN_3D83BB3103")
	
	# 【尾部：唯一抵抗热寂的锚点——诗词】 暗金色，超大字号，占据绝对视觉中心！
	if PlayerState.created_poems.is_empty():
		bbcode += tr("CODE_TOMB_STONE_SCREEN_96317E1F85")
	else:
		for poem in PlayerState.created_poems:
			if poem and poem is Poem:
				bbcode += "[center][font_size=28][color=#daa520]《%s》[/color][/font_size][/center]\n" % poem.name
			else:
				Logging.err('tombstone: invalid poem entry in created_poems')
	# 物理灌注！
	monolith_text.text = bbcode

func _on_button_pressed() -> void:
	Logging.info('TombstoneScreen: exit button pressed, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_return_to_main_menu() -> void:
	Logging.info('TombstoneScreen: return_to_main_menu signal received, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")
