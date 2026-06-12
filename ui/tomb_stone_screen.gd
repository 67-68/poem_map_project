class_name TombstoneScreen extends CanvasLayer

@onready var portrait_rect: TextureRect = $ColorRect/M/H/M/Portrait
@onready var monolith_text: RichTextLabel = $ColorRect/M/H/S/MonolithText
func _ready():
	hide()
	EventBus.show_tombstone_screen.connect(render_entropy_death)


## 核心接口：接收系统级死因，拼装历史巨石碑
func render_entropy_death(cause_text: String) -> void:
	show()
	# 1. 挂载极其冷酷的遗像 (可以根据死因切图，MVP阶段用同一张)
	# portrait_rect.texture = load("res://assets/npc/dufu_dead.png")
	
	# 2. 字符串拼接引擎 (绝对不要在 UI 里 new 任何新节点！)
	var bbcode: String = ""
	
	# 【头部：终局宣判】 红色，居中，冷酷无情
	bbcode += "[center][font_size=36][color=#aa3333]■ 观测停止 ■[/color][/font_size][/center]\n"
	bbcode += "[center][color=#aaaaaa]%s[/color][/center]\n\n" % cause_text
	
	# 【左上角：风化的世俗属性】 极低透明度的灰色（#88888855），代表无人在意 💀
	bbcode += "[color=#88888855][font_size=16]数据快照 | 财富:%d | 官场名声:%d [/font_size][/color]\n\n" % [
		PlayerState.get_stat_val(ENUMS.PROPS.MONEY),
		PlayerState.get_stat_val(ENUMS.PROPS.OFFICIAL_PRESTIGE)
	]
	
	# 【中部：平庸的历史长河】
	#breakpoint
	if not TimeService.get_master_timeline():
		bbcode += "\n[center][color=#911414]可怜的人类，如虫子一般被风吹散，不曾留下任何挣扎的痕迹[/color][/center]\n\n"
	else:
		bbcode += "[color=#cccccc]观测记录：[/color]\n"
		for evt in TimeService.get_master_timeline():
			bbcode += "[color=#999999] - %s 你干了 %s: %s [/color]\n" % [evt.time, evt.name,evt.epitaph_text]
			
		bbcode += "\n[center][color=#555555]...然而这些世俗的挣扎，终将被时间彻底风化...[/color][/center]\n\n"
	
	# 【尾部：唯一抵抗热寂的锚点——诗词】 暗金色，超大字号，占据绝对视觉中心！
	if PlayerState.created_poems.is_empty():
		bbcode += "[center][font_size=40][color=#555555]（绝笔无言，泯然众人）[/color][/font_size][/center]\n"
	else:
		for poem_key in PlayerState.created_poems:
			var poem = Database.get_poem_data(poem_key)
			if poem:
				bbcode += "[center][font_size=42][color=#e2c08d]《%s》[/color][/font_size][/center]\n" % poem.title
				bbcode += "[center][font_size=28][color=#d4b581]%s[/color][/font_size][/center]\n\n" % poem.content
			else:
				Logging.err('can not found poem ' + poem_key)
	# 3. 物理灌注！
	monolith_text.text = bbcode

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
