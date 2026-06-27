extends PanelContainer

var selected_imaginaries: Array[ImagenaryItem] = []

# ──────────────────────────────────────────────
# SubViewport 动态内容 — preload 缓存
# ──────────────────────────────────────────────
const _ABSTRACT_CONCEPT_SCENE := preload("res://ui/poem_uis/abstract_concept.tscn")
const _DETAIL_IMAGINARY_SCENE := preload("res://ui/poem_uis/detail_imaginary.tscn")

func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter')

	# 监听意象变化 — 重建 SubViewport 动态节点
	EventBus.imaginary_changed.connect(on_imaginary_changed)

	# 连接 PoemSlot 的点击信号
	var children = $Panel/VBoxContainer/InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: connecting slot_clicked signals for %d children' % children.size())
	for c in children:
		if c.has_signal("slot_clicked"):
			c.slot_clicked.connect(on_slot_clicked)

	# 延迟重建 SubViewport（等 layout 完成 viewport.size 可用）
	call_deferred("_rebuild_subviewport")

# ──────────────────────────────────────────────
# 事件监听
# ──────────────────────────────────────────────

func on_imaginary_changed() -> void:
	Logging.info('PoemCrafter: imaginary_changed signaled, rebuilding subviewport')
	_rebuild_subviewport()

# ──────────────────────────────────────────────
# SubViewport 排布算法
# 从 Database 拉取所有活跃 ImaginaryTag，用径向布局
# 安放 AbstractConcept，每个挂 N 个 OrbitDetail 子节点
# ──────────────────────────────────────────────

func _rebuild_subviewport() -> void:
	var viewport := _get_subviewport()
	if not viewport:
		Logging.warn('PoemCrafter: SubViewport not found, skipping rebuild')
		return

	# 1. 清除旧动态节点
	for child in viewport.get_children():
		child.queue_free()

	# 2. 收集活跃意象
	var active: Array[ImaginaryTag] = []
	for ima in Database.get_imaginaries_all().values():
		if ima.basic_imaginaries.size() > 0:
			active.append(ima)

	var N := active.size()
	Logging.info('PoemCrafter: rebuilding subviewport with %d active imaginaries' % N)

	if N == 0:
		return

	var vsize := viewport.size
	if vsize.x <= 0 or vsize.y <= 0:
		Logging.warn('PoemCrafter: viewport size zero, retrying deferred')
		call_deferred("_rebuild_subviewport")
		return

	var center := vsize / 2.0
	var concept_radius := 150.0

	for i in N:
		var ima := active[i]
		Logging.info('PoemCrafter: placing abstract concept "%s" (%d fragments)' % [ima.name, ima.basic_imaginaries.size()])

		# 3. 创建抽象概念节点
		var concept := _ABSTRACT_CONCEPT_SCENE.instantiate()
		concept.concept_name = ima.name

		if N == 1:
			concept.position = center
		else:
			var angle := (2.0 * PI * i) / N - PI / 2.0  # 从顶部开始
			concept.position = center + Vector2(cos(angle), sin(angle)) * concept_radius

		viewport.add_child(concept)

		# 4. 创建详细意象轨道节点
		var fragments := ima.basic_imaginaries
		var M := fragments.size()
		for j in M:
			var detail := _DETAIL_IMAGINARY_SCENE.instantiate() as OrbitDetail
			detail.center_target = concept
			detail.semi_major_axis = 60.0 + j * 30.0
			detail.semi_minor_axis = 40.0 + j * 20.0
			detail.phase_offset = (2.0 * PI * j) / M
			detail.orbit_speed = 0.5 + randf() * 0.5  # 微小速度差异避免锁步

			# 拼装 detail 展示文本
			var contexts: Array = fragments[j].get("contexts", [])
			var display_text: String
			if contexts.size() > 0:
				display_text = str(contexts[0])
			else:
				display_text = "…"
			detail.set_detail_text(display_text)

			viewport.add_child(detail)

	Logging.info('PoemCrafter: subviewport rebuild complete')

func _get_subviewport() -> SubViewport:
	return $Panel/VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport as SubViewport

# ──────────────────────────────────────────────
# 槽位渲染 — 不变
# ──────────────────────────────────────────────

func render_slots() -> void:
	Logging.info('PoemCrafter: rendering slots, selected count: %d' % selected_imaginaries.size())
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()

	for i in range(slots.size()):
		var slot := slots[i] as PoemSlot
		slot.remove_theme_stylebox_override("panel")
		if i < selected_imaginaries.size():
			var item := selected_imaginaries[i]
			slot.apply_style(item.current_style)
			slot.apply_text(item.get_text())
		else:
			slot.apply_text('没有灵感...')

# ──────────────────────────────────────────────
# 交互逻辑 — 不变（点击添加意象逻辑暂不动）
# ──────────────────────────────────────────────

func on_item_clicked(imaginary_item: ImagenaryItem) -> void:
	Logging.info('PoemCrafter: item clicked, selected count: %d' % selected_imaginaries.size())
	if selected_imaginaries.size() >= 3:
		Logging.info('PoemCrafter: stop user from adding the fourth imagenary tag')
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
		var result := PoemCraftingCalculator.calculate_poem_grade(imas)
		var text := PoemCraftingCalculator.translate(result.operators)
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = text
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = text
		Logging.info('PoemCrafter: poem text set: %s' % text)

func on_slot_clicked(slot: PoemSlot) -> void:
	Logging.info('PoemCrafter: slot clicked, selected count: %d' % selected_imaginaries.size())
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()
	var slot_index := slots.find(slot)

	if slot_index == -1 or slot_index >= selected_imaginaries.size():
		Logging.warn('PoemCrafter: slot clicked but no item occupying at index %d' % slot_index)
		return

	Logging.info('PoemCrafter: removing item at index %d from array' % slot_index)
	var item := selected_imaginaries[slot_index]
	selected_imaginaries.remove_at(slot_index)
	item.show()
	render_slots()
	Logging.info('PoemCrafter: slot cleared, new selected count: %d' % selected_imaginaries.size())

func _on_button_pressed() -> void:
	if selected_imaginaries.size() != 3:
		Logging.warn('PoemCrafter: selected count not 3, cannot craft poem')
		return
	Logging.info('PoemCrafter: button pressed, crafting poem')
	var imas: Array[ImaginaryTag] = []
	for item in selected_imaginaries:
		imas.append(item.imaginary_tag)
	Logging.info('PoemCrafter: collecting %d imaginaries for crafting' % imas.size())

	# 调用诗词评价引擎
	var result := PoemCraftingCalculator.calculate_poem_grade(imas)
	Logging.info('PoemCrafter: poem grade calculated, %d operators' % result.operators.size())

	# 执行结算算子
	result.operate()

	# 阅后即焚 — 删除投入的概念
	ImaginaryComprehender.consume_concepts(imas)

	Logging.info('PoemCrafter: scanning for poem events')

	for i in imas:
		for entry in i.basic_imaginaries:
			var blueprint_id = entry.get("blueprint_id", "")
			if not blueprint_id.is_empty():
				PlayerState.current_action_tags.append(blueprint_id)

	EventManager.scan_poem_events(imas)
	Logging.info('PoemCrafter: poem crafting complete')

	# 清空状态
	Logging.info('PoemCrafter: clearing selected imaginaries')
	for item in selected_imaginaries:
		item.show()
	selected_imaginaries.clear()
	render_slots()

	# 重建 SubViewport（consumed 后碎片数量变化）
	_rebuild_subviewport()


# ======================================================
# 浮现/退出动画（供 PoemCreationPage 调用）
# ======================================================

## 卷轴浮入：modulate 0→1 + 微上浮
func show_with_animation() -> void:
	var original_mod := modulate
	var original_pos := position
	modulate = Color(1, 1, 1, 0)
	position = original_pos + Vector2(0, 15)
	show()

	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate", original_mod, 0.4)
	tw.tween_property(self, "position", original_pos, 0.4)
	await tw.finished
	Logging.info("PoemCrafter: show_with_animation 完成")


## 卷轴淡出
func hide_with_animation() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "position:y", position.y + 10, 0.3)
	await tw.finished
	hide()
	Logging.info("PoemCrafter: hide_with_animation 完成")
