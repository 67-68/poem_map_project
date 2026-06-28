extends PanelContainer

## 当前选中用于创作诗词的 ImaginaryTag（最多 3 个）
var selected_imaginaries: Array[ImaginaryTag] = []

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

	# 连接 SubViewportContainer gui_input 检测 SubViewport 内部点击
	var svp_container := $Panel/VBoxContainer/HBoxContainer/SubViewportContainer
	svp_container.gui_input.connect(_on_subviewport_gui_input)
	Logging.info('PoemCrafter: connected subviewport gui_input')

	# 延迟重建 SubViewport（等 layout 完成 viewport.size 可用）
	call_deferred("_rebuild_subviewport")


# ──────────────────────────────────────────────
# SubViewport 点击检测 — 物理空间拾取
# ──────────────────────────────────────────────

func _on_subviewport_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	Logging.info('PoemCrafter: subviewport click button=%d pos=%s' % [event.button_index, event.position])

	var viewport := _get_subviewport()
	if not viewport:
		Logging.warn('PoemCrafter: no subviewport for click')
		return

	# 转换到 SubViewport 局部坐标
	var local_pos = viewport.canvas_transform.affine_inverse() * event.position
	Logging.info('PoemCrafter: local pos=%s viewport.size=%s' % [local_pos, viewport.size])

	# 无效位置跳过
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > viewport.size.x or local_pos.y > viewport.size.y:
		Logging.info('PoemCrafter: click outside viewport bounds')
		return

	var space_state := viewport.world_2d.direct_space_state
	if not space_state:
		Logging.warn('PoemCrafter: no space_state available')
		return

	var query := PhysicsPointQueryParameters2D.new()
	query.position = local_pos
	query.collide_with_areas = true
	query.collision_mask = 1

	var results := space_state.intersect_point(query)
	Logging.info('PoemCrafter: intersect_point results=%d' % results.size())

	for r in results:
		var collider := r.get("collider") as Node
		if not collider:
			continue
		Logging.info('PoemCrafter: hit node=%s class=%s' % [collider.name, collider.get_class()])

		if collider is AbstractConcept:
			Logging.info('PoemCrafter: AbstractConcept hit=%s btn=%d' % [collider.concept_name, event.button_index])
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					on_concept_selected(collider.imaginary_tag)
					return
				MOUSE_BUTTON_RIGHT:
					on_concept_merge_requested(collider.imaginary_tag)
					return

	Logging.info('PoemCrafter: no AbstractConcept at click position')


# ──────────────────────────────────────────────
# 事件监听
# ──────────────────────────────────────────────

func on_imaginary_changed() -> void:
	Logging.info('PoemCrafter: imaginary_changed signaled, rebuilding subviewport')
	_rebuild_subviewport()

# ──────────────────────────────────────────────
# SubViewport 排布算法
# ──────────────────────────────────────────────

func _rebuild_subviewport() -> void:
	var viewport := _get_subviewport()
	if not viewport:
		Logging.warn('PoemCrafter: SubViewport not found, skipping rebuild')
		return

	# 清除旧动态节点
	for child in viewport.get_children():
		child.queue_free()

	# 收集活跃意象：有碎片 OR 已合并（显示合并态）
	var active: Array[ImaginaryTag] = []
	for ima in Database.get_imaginaries_all().values():
		if selected_imaginaries.has(ima):
			continue
		if ima.basic_imaginaries.size() == 0 and ima.current_tier == 0:
			continue
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
		Logging.info('PoemCrafter: placing abstract concept "%s" (fragments=%d, tier=%d, level=%d)' %
			[ima.name, ima.basic_imaginaries.size(), ima.current_tier, ima.current_level])

		var concept := _ABSTRACT_CONCEPT_SCENE.instantiate()
		concept.concept_name = ima.name
		concept.imaginary_tag = ima

		# 连接交互信号（保留作为 fallback）
		concept.concept_selected.connect(on_concept_selected)
		concept.concept_merge_requested.connect(on_concept_merge_requested)

		if N == 1:
			concept.position = center
		else:
			var angle := (2.0 * PI * i) / N - PI / 2.0
			concept.position = center + Vector2(cos(angle), sin(angle)) * concept_radius

		viewport.add_child(concept)

		# 创建 OrbitDetail 节点（仅当有未合并碎片时）
		var fragments := ima.basic_imaginaries
		var M := fragments.size()
		for j in M:
			var detail := _DETAIL_IMAGINARY_SCENE.instantiate() as OrbitDetail
			detail.center_target = concept
			detail.semi_major_axis = 60.0 + j * 30.0
			detail.semi_minor_axis = 40.0 + j * 20.0
			detail.phase_offset = (2.0 * PI * j) / M
			detail.orbit_speed = 0.5 + randf() * 0.5

			var contexts: Array = fragments[j].get("contexts", [])
			var display_text: String = str(contexts[0]) if contexts.size() > 0 else "..."
			detail.set_detail_text(display_text)

			viewport.add_child(detail)

	Logging.info('PoemCrafter: subviewport rebuild complete')


func _get_subviewport() -> SubViewport:
	return $Panel/VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport as SubViewport


# ──────────────────────────────────────────────
# 槽位渲染
# ──────────────────────────────────────────────

func render_slots() -> void:
	Logging.info('PoemCrafter: rendering slots, selected count: %d' % selected_imaginaries.size())
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()

	for i in range(slots.size()):
		var slot := slots[i] as PoemSlot
		slot.remove_theme_stylebox_override("panel")
		if i < selected_imaginaries.size():
			var ima := selected_imaginaries[i]
			var style := _build_style_from_tag(ima)
			slot.apply_style(style)
			slot.apply_text(ima.name)
		else:
			slot.apply_text('没有灵感...')


func _build_style_from_tag(ima: ImaginaryTag) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)

	var tier := ima.current_tier
	var level := ima.current_level

	match level:
		1:
			style.border_width_bottom = 1
			style.border_color = Color(0.5, 0.5, 0.5, 0.5)
		2:
			style.set_border_width_all(1)
			style.border_color = Color.WHITE
		3:
			style.set_border_width_all(1)
			style.border_color = Color.RED
			style.shadow_color = Color(1.0, 0.0, 0.0, 0.6)
			style.shadow_size = 8

	match tier:
		3:
			style.border_color = Color.GOLD
			style.shadow_color = Color.GOLD
			style.shadow_size = 6
		2:
			style.border_color = Color.SLATE_GRAY
			style.shadow_color = Color(0.2, 0.2, 0.2, 0.6)
			style.shadow_size = 4
		1:
			style.border_color = Color(0.3, 0.4, 0.2, 0.7)
			style.shadow_color = Color(0.1, 0.15, 0.05, 0.5)
			style.shadow_size = 2

	return style


# ──────────────────────────────────────────────
# 交互逻辑
# ──────────────────────────────────────────────

func on_concept_selected(ima: ImaginaryTag) -> void:
	Logging.info('PoemCrafter: concept selected: %s, selected count: %d' % [ima.name, selected_imaginaries.size()])

	if selected_imaginaries.size() >= 3:
		Logging.info('PoemCrafter: stop user from adding the fourth imaginary tag')
		return

	selected_imaginaries.append(ima)
	render_slots()
	_rebuild_subviewport()

	if selected_imaginaries.size() == 3:
		Logging.info('PoemCrafter: reached max level, calculating poem')
		var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries)
		var text := PoemCraftingCalculator.translate(result.operators)
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = text
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = text
		Logging.info('PoemCrafter: poem text set: %s' % text)


func on_concept_merge_requested(ima: ImaginaryTag) -> void:
	Logging.info('PoemCrafter: merge requested for concept: %s' % ima.name)

	if selected_imaginaries.has(ima):
		Logging.warn('PoemCrafter: concept already selected, cannot merge')
		return

	var success := ImaginaryComprehender.merge_category(ima.uuid)
	if not success:
		Logging.warn('PoemCrafter: merge failed for concept: %s' % ima.name)
		return

	EventBus.imaginary_changed.emit()
	_rebuild_subviewport()


func on_slot_clicked(slot: PoemSlot) -> void:
	Logging.info('PoemCrafter: slot clicked, selected count: %d' % selected_imaginaries.size())
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()
	var slot_index := slots.find(slot)

	if slot_index == -1 or slot_index >= selected_imaginaries.size():
		Logging.warn('PoemCrafter: slot clicked but no tag occupying at index %d' % slot_index)
		return

	Logging.info('PoemCrafter: removing tag at index %d' % slot_index)
	selected_imaginaries.remove_at(slot_index)
	render_slots()

	if selected_imaginaries.size() < 3:
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = ""
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "代价是..."

	_rebuild_subviewport()
	Logging.info('PoemCrafter: slot cleared, new selected count: %d' % selected_imaginaries.size())


func _on_button_pressed() -> void:
	if selected_imaginaries.size() != 3:
		Logging.warn('PoemCrafter: selected count not 3, cannot craft poem')
		return
	Logging.info('PoemCrafter: button pressed, crafting poem')

	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries)
	Logging.info('PoemCrafter: poem grade calculated, %d operators' % result.operators.size())

	result.operate()
	ImaginaryComprehender.consume_concepts(selected_imaginaries)

	Logging.info('PoemCrafter: scanning for poem events')
	for ima in selected_imaginaries:
		for entry in ima.basic_imaginaries:
			var blueprint_id = entry.get("blueprint_id", "")
			if not blueprint_id.is_empty():
				PlayerState.current_action_tags.append(blueprint_id)

	EventManager.scan_poem_events(selected_imaginaries)
	Logging.info('PoemCrafter: poem crafting complete')

	Logging.info('PoemCrafter: clearing selected imaginaries')
	selected_imaginaries.clear()
	render_slots()
	_rebuild_subviewport()


# ======================================================
# 浮现/退出动画
# ======================================================

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


func hide_with_animation() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "position:y", position.y + 10, 0.3)
	await tw.finished
	hide()
	Logging.info("PoemCrafter: hide_with_animation 完成")
