extends HBoxContainer

var selected_imaginaries: Array[ImagenaryItem] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter')
	setup_imagenaries()
	# 监听 imaginary_changed，但只在意象数量变化时才重建
	EventBus.imaginary_changed.connect(on_imaginary_changed)
	var children = $InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: connecting slot_clicked signals for %d children' % children.size())
	for c in children:
		c.slot_clicked.connect(on_slot_clicked)

func on_imaginary_changed():
	# 检查意象数量是否变化，只有数量变化才重建
	var current_count = $ImagenaryScroll/HFlowContainer.get_children().size()
	var new_count = 0
	for ima in Database.imaginaries.values():
		if ima.basic_imaginaries.size() > 0:
			new_count += 1

	if current_count != new_count:
		Logging.info('PoemCrafter: imaginary count changed from %d to %d, rebuilding' % [current_count, new_count])
		setup_imagenaries()
	else:
		Logging.info('PoemCrafter: imaginary count unchanged, skipping rebuild (let items update themselves)')

func setup_imagenaries():
	Logging.info('PoemCrafter: setting up imaginaries')

	# 清空选中的意象（因为 UI 即将被销毁）
	for item in selected_imaginaries:
		if is_instance_valid(item):
			item.show()
	selected_imaginaries.clear()
	render_slots()

	var existing_children = $ImagenaryScroll/HFlowContainer.get_children()
	Logging.info('PoemCrafter: clearing %d existing children' % existing_children.size())
	for c in existing_children:
		c.queue_free()
	var active_imaginaries = 0
	for ima in Database.imaginaries.values():
		if ima.basic_imaginaries.size() > 0:
			active_imaginaries += 1
			Logging.info('PoemCrafter: creating item for imaginary with %d basic imaginaries' % ima.basic_imaginaries.size())
			var item = preload("res://ui/imaginery_item.tscn").instantiate()
			item.init(ima)
			item.imagenery_item_clicked.connect(on_item_clicked)

			$ImagenaryScroll/HFlowContainer.add_child(item)
	Logging.info('PoemCrafter: setup complete, created %d items' % active_imaginaries)

func render_slots():
	Logging.info('PoemCrafter: rendering slots, selected count: %d' % selected_imaginaries.size())
	var slots = $InputImagPanel/H.get_children()

	# 渲染所有槽位
	for i in range(slots.size()):
		var slot = slots[i] as PoemSlot
		slot.remove_theme_stylebox_override("panel")
		if i < selected_imaginaries.size():
			# 有意象的槽位
			var item = selected_imaginaries[i]
			slot.apply_style(item.current_style)
			slot.apply_text(item.get_text())
		else:
			# 空槽位
			slot.apply_text('没有灵感...')

func refresh_image():
	var level = selected_imaginaries.size()
	Logging.info('PoemCrafter: refreshing image for level %d' % level)
	var tex: Texture2D = null
	match level:
		0:
			tex = TextureResLoader.get_background("bg_poem_creation_1")
			Logging.info('PoemCrafter: loading background 1 for level 0')
		1:
			tex = TextureResLoader.get_background("bg_poem_creation_2")
			Logging.info('PoemCrafter: loading background 2 for level 1')
		2:
			tex = TextureResLoader.get_background("bg_poem_creation_3")
			Logging.info('PoemCrafter: loading background 3 for level 2')
		3:
			tex = TextureResLoader.get_background("bg_study_quiet")
			Logging.info('PoemCrafter: loading background for level 3')
		_:
			Logging.warn('PoemCrafter: unknown level %d' % level)

	$InputImagPanel/MarginContainer/TextureRect.texture = tex

func on_item_clicked(imaginary_item: ImagenaryItem):
	Logging.info('PoemCrafter: item clicked, selected count: %d' % selected_imaginaries.size())
	if selected_imaginaries.size() >= 3:
		Logging.info('stop user from adding the fourth imagenary tag')
		return

	Logging.info('PoemCrafter: adding imaginary_item to array and hiding it')
	imaginary_item.hide()
	selected_imaginaries.append(imaginary_item)
	render_slots()

	if selected_imaginaries.size() == 3:
		Logging.info('PoemCrafter: reached max level, calculating poem')
		var imas: Array[ImaginaryTag] = []
		for item in selected_imaginaries:
			imas.append(item.imaginary_tag)
		Logging.info('PoemCrafter: calculating poem from %d imaginaries' % imas.size())
		var cost = PoemCraftingCalculator.calculate(imas)
		var text = PoemCraftingCalculator.translate(cost)
		$InputImagPanel/Button.tooltip_text = text
		$InputImagPanel/RichTextLabel.text = text
		Logging.info('PoemCrafter: poem text set: %s' % text)

	refresh_image()

func on_slot_clicked(slot: PoemSlot):
	Logging.info('PoemCrafter: slot clicked, selected count: %d' % selected_imaginaries.size())
	var slots = $InputImagPanel/H.get_children()
	var slot_index = slots.find(slot)

	if slot_index == -1 or slot_index >= selected_imaginaries.size():
		Logging.warn('PoemCrafter: slot clicked but no item occupying at index %d' % slot_index)
		return

	Logging.info('PoemCrafter: removing item at index %d from array' % slot_index)
	var item = selected_imaginaries[slot_index]
	selected_imaginaries.remove_at(slot_index)
	item.show()
	render_slots()
	Logging.info('PoemCrafter: slot cleared, new selected count: %d' % selected_imaginaries.size())

	refresh_image()

func _on_button_pressed() -> void:
	#breakpoint
	if selected_imaginaries.size() != 3:
		Logging.warn('selected count not 3, cannot craft poem')
		return
	Logging.info('PoemCrafter: button pressed, crafting poem')
	var imas: Array[ImaginaryTag] = []
	for item in selected_imaginaries:
		imas.append(item.imaginary_tag)
	Logging.info('PoemCrafter: collecting %d imaginaries for crafting' % imas.size())
	var ops = PoemCraftingCalculator.calculate(imas)
	Logging.info('PoemCrafter: calculated %d operations' % ops.size())
	for op in ops:
		Logging.info('PoemCrafter: executing operation')
		op.operate()

	#breakpoint
	Logging.info('PoemCrafter: scanning for poem events')

	for i in imas:
		for tag in i.basic_imaginaries:
			# 🔧 标准化标签：确保三段式标签转换为四段式
			var normalized_tag = TagManager.normalize_3part_depreciated_tag(tag)
			PlayerState.current_action_tags.append(normalized_tag)

	EventManager.scan_poem_events(imas)
	Logging.info('PoemCrafter: updating l3_thresholds for %d imaginaries' % imas.size())
	for i in imas:
		if i:
			var old_threshold = i.l3_threshold
			i.l3_threshold += 3
			i.current_level = 1
			Logging.info('PoemCrafter: updated l3_threshold from %d to %d' % [old_threshold, i.l3_threshold])
	Logging.info('PoemCrafter: poem crafting complete')

	# 清空状态
	Logging.info('PoemCrafter: clearing selected imaginaries')
	for item in selected_imaginaries:
		item.show()
	selected_imaginaries.clear()
	render_slots()
