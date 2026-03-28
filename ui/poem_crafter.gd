extends HBoxContainer

@export var current_level = 0 # 0-2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_imagenaries()
	for c in $InputImagPanel/HBoxContainer.get_children():
		c.slot_clicked.connect(on_slot_clicked)

func setup_imagenaries():
	for c in $ImagenaryScroll/HFlowContainer.get_children():
		c.queue_free()
	for ima in Global.imaginaries.values():
		if ima.basic_imaginaries.size() >= 0:
			var item = preload("res://ui/imagenery_item.tscn").instantiate()
			item.init(ima)
			item.imagenery_item_clicked.connect(on_item_clicked)
			$ImagenaryScroll/HFlowContainer.add_child(item)

func refresh_image():
	var tex: Texture2D = null
	match current_level:
		0:
			tex = TextureResLoader.get_background("bg_poem_creation_1")
		1:
			tex = TextureResLoader.get_background("bg_poem_creation_2")
		2:
			tex = TextureResLoader.get_background("bg_poem_creation_3")
	
	$InputImagPanel/MarginContainer/TextureRect.texture = tex

func on_item_clicked(item: ImagenaryItem):
	if current_level == 2:
		Logging.info('stop user from adding the fourth imagenary tag') 
		return
	
	item.hide()
	current_level += 1
	var items = $ImagenaryScroll/HFlowContainer.get_children()
	for i in items:
		var slot = i as PoemSlot
		if not slot.item_occupying:
			slot.apply_style(item.current_style)
			slot.apply_text(item.get_text())
			slot.item_occupying = i
			break
	
	if current_level == 2:
		var imas = []
		for c in $ImagenaryScroll/HFlowContainer.get_children():
			imas.append(c.item_occupying)
		var text = PoemCraftingCalculator.translate(PoemCraftingCalculator.calculate(imas))
		$InputImagPanel/Button.tooltip_text = text
		$InputImagPanel/RichTextLabel.text = text

func on_slot_clicked(slot: PoemSlot):
	var item = slot.item_occupying
	item.show()
	slot.item_occupying = null
	current_level -= 1
	# 返回原本的style
	slot.remove_theme_stylebox_override("panel")
	slot.apply_text('没有灵感...')

func _on_button_pressed() -> void:
	var imas = []
	for c in $ImagenaryScroll/HFlowContainer.get_children():
		imas.append(c.item_occupying)
	var ops = PoemCraftingCalculator.calculate(imas)
	for op in ops:
		op.operate()
	
	EventManager.scan_poem_events(imas)
	for i in imas:
		i.l3_threshold += 3

	
