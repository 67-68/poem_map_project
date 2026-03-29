extends HBoxContainer

@export var current_level := -1: # -1 -> 2
	set(value):
		#breakpoint
		Logging.debug('current level is ' + str(value))
		current_level = value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter')
	setup_imagenaries()
	Global.imaginary_changed.connect(setup_imagenaries)
	var children = $InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: connecting slot_clicked signals for %d children' % children.size())
	for c in children:
		c.slot_clicked.connect(on_slot_clicked)

func setup_imagenaries():
	Logging.info('PoemCrafter: setting up imaginaries')
	var existing_children = $ImagenaryScroll/HFlowContainer.get_children()
	Logging.info('PoemCrafter: clearing %d existing children' % existing_children.size())
	for c in existing_children:
		c.queue_free()
	var active_imaginaries = 0
	for ima in Global.imaginaries.values():
		if ima.basic_imaginaries.size() > 0:
			active_imaginaries += 1
			Logging.info('PoemCrafter: creating item for imaginary with %d basic imaginaries' % ima.basic_imaginaries.size())
			var item = preload("res://ui/imaginery_item.tscn").instantiate()
			item.init(ima)
			item.imagenery_item_clicked.connect(on_item_clicked)

			$ImagenaryScroll/HFlowContainer.add_child(item)
	Logging.info('PoemCrafter: setup complete, created %d items' % active_imaginaries)

func refresh_image():
	Logging.info('PoemCrafter: refreshing image for current_level %d' % current_level)
	var tex: Texture2D = null
	match current_level:
		-1:
			tex = TextureResLoader.get_background("bg_poem_creation_1")
			Logging.info('PoemCrafter: loading background 1 for level -1, 0 complete')
		0:
			tex = TextureResLoader.get_background("bg_poem_creation_2")
			Logging.info('PoemCrafter: loading background 2 for level 0, 1 complete')
		1:
			tex = TextureResLoader.get_background("bg_poem_creation_3")
			Logging.info('PoemCrafter: loading background 3 for level 1, 2 complete')
		2:
			tex = TextureResLoader.get_background("bg_study_quiet")
			Logging.info('PoemCrafter: loading background 3 for level 2, 3 complete')
		_:
			Logging.warn('PoemCrafter: unknown current_level %d' % current_level)
	
	$InputImagPanel/MarginContainer/TextureRect.texture = tex

func on_item_clicked(imaginary_item: ImagenaryItem):
	Logging.info('PoemCrafter: item clicked at current_level %d' % current_level)
	if current_level == 2:
		Logging.info('stop user from adding the fourth imagenary tag') 
		return
	
	Logging.info('PoemCrafter: adding imaginary_item to slot, hiding imaginary_item and incrementing level')
	imaginary_item.hide()
	current_level += 1
	var slots = $InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: checking %d available slots' % slots.size())
	for i in slots:
		var slot = i as PoemSlot
		if not slot.item_occupying:
			Logging.info('PoemCrafter: found empty slot, applying imaginary_item')
			slot.apply_style(imaginary_item.current_style)
			slot.apply_text(imaginary_item.get_text())
			slot.item_occupying = imaginary_item
			break
	
	if current_level == 2:
		Logging.info('PoemCrafter: reached max level, calculating poem')
		var imas: Array[ImaginaryTag] = []
		for c in $InputImagPanel/H.get_children():
			imas.append(c.item_occupying.imaginary_tag)
		Logging.info('PoemCrafter: calculating poem from %d imaginaries' % imas.size())
		var cost = PoemCraftingCalculator.calculate(imas)
		var text = PoemCraftingCalculator.translate(cost)
		$InputImagPanel/Button.tooltip_text = text
		$InputImagPanel/RichTextLabel.text = text
		Logging.info('PoemCrafter: poem text set: %s' % text)
	
	refresh_image()

func on_slot_clicked(slot: PoemSlot):
	Logging.info('PoemCrafter: slot clicked, current_level: %d' % current_level)
	var item = slot.item_occupying
	if not item:
		Logging.warn('PoemCrafter: slot clicked but no item occupying')
		return
	Logging.info('PoemCrafter: removing item from slot and decrementing level')
	#breakpoint
	item.show()
	slot.item_occupying = null
	current_level -= 1
	# 返回原本的style
	slot.remove_theme_stylebox_override("panel")
	slot.apply_text('没有灵感...')
	Logging.info('PoemCrafter: slot cleared, new current_level: %d' % current_level)

	refresh_image()

func _on_button_pressed() -> void:
	Logging.info('PoemCrafter: button pressed, crafting poem')
	var imas: Array[ImaginaryTag] = []
	for c in $InputImagPanel/H.get_children():
		imas.append(c.item_occupying.imaginary_tag)
	Logging.info('PoemCrafter: collecting %d imaginaries for crafting' % imas.size())
	var ops = PoemCraftingCalculator.calculate(imas)
	Logging.info('PoemCrafter: calculated %d operations' % ops.size())
	for op in ops:
		Logging.info('PoemCrafter: executing operation')
		op.operate()
	
	breakpoint
	Logging.info('PoemCrafter: scanning for poem events')
	EventManager.scan_poem_events(imas)
	Logging.info('PoemCrafter: updating l3_thresholds for %d imaginaries' % imas.size())
	for i in imas:
		if i:
			var old_threshold = i.l3_threshold
			i.l3_threshold += 3
			Logging.info('PoemCrafter: updated l3_threshold from %d to %d' % [old_threshold, i.l3_threshold])
	Logging.info('PoemCrafter: poem crafting complete')

	
