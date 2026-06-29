extends PanelContainer

## 诗词创作面板 — V4: 动态推导 + POEM_TYPE + 双层校验 + 拒写

## 当前选中用于创作诗词的 ImaginaryConcept（最多 3 个）
var selected_imaginaries: Array[ImaginaryConcept] = []

## 当前选中的诗词类型（-1 = 未选择）
var selected_poem_type: int = -1

# ──────────────────────────────────────────────
# SubViewport 动态内容 — preload 缓存
# ──────────────────────────────────────────────
const _ABSTRACT_CONCEPT_SCENE := preload("res://ui/poem_uis/abstract_concept.tscn")
const _DETAIL_IMAGINARY_SCENE := preload("res://ui/poem_uis/detail_imaginary.tscn")

## 当前 hover 的 AbstractConcept（用于 hover 高亮）
var _hovered_concept: AbstractConcept = null
## 每个 AbstractConcept 的原始 modulate（hover 恢复用）
var _concept_original_modulates: Dictionary = {}  # AbstractConcept → Color


func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter V4')

	EventBus.imaginary_changed.connect(on_imaginary_changed)

	# 连接 PoemSlot 的点击信号
	var children = $Panel/VBoxContainer/InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: connecting slot_clicked signals for %d children' % children.size())
	for c in children:
		if c.has_signal("slot_clicked"):
			c.slot_clicked.connect(on_slot_clicked)

	# 连接 SubViewportContainer gui_input
	var svp_container := $Panel/VBoxContainer/HBoxContainer/SubViewportContainer
	svp_container.gui_input.connect(_on_subviewport_gui_input)

	# 连接 POEM_TYPE toggle buttons
	_connect_poem_type_buttons()

	# "开始创作"按钮 — 由 tscn 的 _on_button_pressed() 命名约定自动连接
	# "撕毁卷轴"按钮 — 位于 $Panel/Button，手动连接
	var tear_btn := $Panel/Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	call_deferred("_rebuild_subviewport")


# ──────────────────────────────────────────────
# POEM_TYPE Toggle Buttons
# ──────────────────────────────────────────────

func _connect_poem_type_buttons() -> void:
	var type_vbox := $Panel/VBoxContainer/HBoxContainer/VBoxContainer
	var type_buttons := type_vbox.get_children()
	var labels := ["干谒", "应制", "登高", "怀古", "羇旅", "山水"]
	for i in range(min(type_buttons.size(), labels.size())):
		var btn = type_buttons[i]
		if btn is Button:
			btn.text = labels[i]
			btn.toggled.connect(_on_poem_type_toggled.bind(i))

	# 默认选中第一个
	if type_buttons.size() > 0 and type_buttons[0] is Button:
		type_buttons[0].button_pressed = true
		selected_poem_type = 0


func _on_poem_type_toggled(button_pressed: bool, type_idx: int) -> void:
	if button_pressed:
		selected_poem_type = type_idx
		Logging.info('PoemCrafter: POEM_TYPE selected = %d (%s)' % [type_idx, ENUMS.POEM_TYPE.keys()[type_idx]])


# ──────────────────────────────────────────────
# SubViewport 输入检测
# ──────────────────────────────────────────────

func _on_subviewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	Logging.info('PoemCrafter: subviewport click button=%d pos=%s' % [event.button_index, event.position])

	var viewport := _get_subviewport()
	if not viewport:
		Logging.warn('PoemCrafter: no subviewport for click')
		return

	var local_pos = viewport.canvas_transform.affine_inverse() * event.position

	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > viewport.size.x or local_pos.y > viewport.size.y:
		return

	var space_state := viewport.world_2d.direct_space_state
	if not space_state:
		return

	var query := PhysicsPointQueryParameters2D.new()
	query.position = local_pos
	query.collide_with_areas = true
	query.collision_mask = 1

	var results := space_state.intersect_point(query)

	for r in results:
		var collider := r.get("collider") as Node
		if not collider:
			continue

		if collider is AbstractConcept:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					AudioManager.play_sfx_category("leather")
					on_concept_selected(collider.imaginary_tag)
					return
				MOUSE_BUTTON_RIGHT:
					AudioManager.play_sfx_category("stone_throw_in_lake")
					on_concept_merge_requested(collider.imaginary_tag)
					return

	Logging.info('PoemCrafter: no AbstractConcept at click position')


func _update_hover(mouse_pos: Vector2) -> void:
	var viewport := _get_subviewport()
	if not viewport:
		return

	var local_pos = viewport.canvas_transform.affine_inverse() * mouse_pos
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x > viewport.size.x or local_pos.y > viewport.size.y:
		_clear_hover()
		return

	var space_state := viewport.world_2d.direct_space_state
	if not space_state:
		return

	var query := PhysicsPointQueryParameters2D.new()
	query.position = local_pos
	query.collide_with_areas = true
	query.collision_mask = 1

	var results := space_state.intersect_point(query)
	for r in results:
		var collider := r.get("collider") as Node
		if collider is AbstractConcept:
			if _hovered_concept != collider:
				_clear_hover()
				_hovered_concept = collider
				_apply_hover_enter(collider)
			return

	_clear_hover()


func _apply_hover_enter(concept: AbstractConcept) -> void:
	var hover_color := concept.modulate.lerp(Color.WHITE, 0.25)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(concept, "modulate", hover_color, 0.12)


func _clear_hover() -> void:
	if not _hovered_concept:
		return
	var concept := _hovered_concept
	_hovered_concept = null
	var original_color: Color = _concept_original_modulates.get(concept, concept.modulate)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(concept, "modulate", original_color, 0.15)


# ──────────────────────────────────────────────
# 事件监听
# ──────────────────────────────────────────────

func on_imaginary_changed() -> void:
	Logging.info('PoemCrafter: imaginary_changed signaled, rebuilding subviewport')
	_rebuild_subviewport()


# ──────────────────────────────────────────────
# SubViewport 排布算法 — V4 动态推导版
# ──────────────────────────────────────────────

func _rebuild_subviewport() -> void:
	var viewport := _get_subviewport()
	if not viewport:
		Logging.warn('PoemCrafter: SubViewport not found, skipping rebuild')
		return

	_clear_hover()
	_concept_original_modulates.clear()
	for child in viewport.get_children():
		child.queue_free()

	var vsize := viewport.size
	if vsize.x <= 0 or vsize.y <= 0:
		Logging.warn('PoemCrafter: viewport size zero, retrying deferred')
		call_deferred("_rebuild_subviewport")
		return

	# 从 ImaginaryComprehender 获取活跃的 concepts
	var active = ImaginaryComprehender.get_active_concepts()
	var concept_list: Array[ImaginaryConcept] = []
	for key in active:
		var c = active[key]
		if c is ImaginaryConcept and not selected_imaginaries.has(c):
			concept_list.append(c)

	var N := concept_list.size()
	Logging.info('PoemCrafter: rebuilding subviewport with %d active concepts' % N)
	if N == 0:
		return

	var center := vsize / 2.0
	var concept_radius := 150.0

	for i in N:
		var concept := concept_list[i]
		var concept_key = concept.uuid
		var detail_imaginaries = ImaginaryComprehender.get_imaginaries_for_concept(concept_key)
		var fragment_count = detail_imaginaries.size()

		Logging.info('PoemCrafter: placing concept "%s" (key=%s, fragments=%d, tier=%d, level=%d)' %
			[concept.name, concept_key, fragment_count, concept.current_tier, concept.current_level])

		var node := _ABSTRACT_CONCEPT_SCENE.instantiate() as AbstractConcept
		node.concept_name = concept.name
		node.imaginary_tag = concept

		node.concept_selected.connect(on_concept_selected)
		node.concept_merge_requested.connect(on_concept_merge_requested)
		node.merge_animation_finished.connect(on_merge_animation_finished)

		# 已合并态：直接设置 tier 颜色
		if concept.current_tier > 0:
			node.modulate = AbstractConcept.TIER_COLORS.get(concept.current_tier, Color.WHITE)

		if N == 1:
			node.position = center
		else:
			var angle := (2.0 * PI * i) / N - PI / 2.0
			node.position = center + Vector2(cos(angle), sin(angle)) * concept_radius

		viewport.add_child(node)
		_concept_original_modulates[node] = node.modulate

		# 创建 OrbitDetail 节点 — 从动态推导的 Imaginary 列表
		for j in range(detail_imaginaries.size()):
			var imag = detail_imaginaries[j] as Imaginary
			if not imag:
				continue

			var detail := _DETAIL_IMAGINARY_SCENE.instantiate() as OrbitDetail
			detail.center_target = node
			detail.semi_major_axis = 60.0 + j * 30.0
			detail.semi_minor_axis = 40.0 + j * 20.0
			detail.phase_offset = (2.0 * PI * j) / max(detail_imaginaries.size(), 1)
			detail.orbit_speed = 0.5 + randf() * 0.5

			# 第一行：perception 文本，第二行：Imaginary name（暗红小字）
			var display_text := ""
			for tag in imag.detail_imaginaries:
				var perception = imag.perceptions.get(tag, "")
				if not perception.is_empty():
					display_text = perception
					break
			if display_text.is_empty():
				display_text = imag.name

			display_text += "\n[color=darkred][font_size=10]%s[/font_size][/color]" % imag.name
			detail.set_detail_text(display_text)

			node.add_child(detail)

		# 碎片 >= 2 时启动合并就绪闪烁
		if fragment_count >= ImaginaryConcept.l2_threshold and concept.current_tier == 0:
			node.call_deferred("start_merge_ready_blink")

	Logging.info('PoemCrafter: subviewport rebuild complete')


# ──────────────────────────────────────────────
# Concept 选择 / 合并
# ──────────────────────────────────────────────

func on_concept_selected(ima: ImaginaryConcept) -> void:
	Logging.info('PoemCrafter: concept selected: %s' % ima.name)

	if selected_imaginaries.has(ima):
		Logging.warn('PoemCrafter: concept already selected')
		return

	if selected_imaginaries.size() >= 3:
		Logging.info('PoemCrafter: max 3 concepts reached')
		return

	selected_imaginaries.append(ima)
	render_slots()
	_rebuild_subviewport()

	if selected_imaginaries.size() == 3:
		Logging.info('PoemCrafter: 3 concepts selected, previewing grade')
		var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, selected_poem_type)
		if result.passed:
			var text := PoemCraftingCalculator.translate(result.operators)
			$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = text
			$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = text
		else:
			$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = result.penalty_text


func on_concept_merge_requested(ima: ImaginaryConcept) -> void:
	Logging.info('PoemCrafter: merge requested for concept: %s' % ima.name)

	if selected_imaginaries.has(ima):
		Logging.warn('PoemCrafter: concept already selected, cannot merge')
		return

	if not ImaginaryComprehender.can_merge(ima.uuid):
		Logging.warn('PoemCrafter: merge precondition failed for: %s (need ≥2 fragments)' % ima.name)
		return

	var concept := _find_concept_for_tag(ima)
	if not concept:
		Logging.info('PoemCrafter: concept node not found, direct merge')
		_direct_merge(ima)
		return

	concept.play_merge_animation(1)


func _find_concept_for_tag(ima: ImaginaryConcept) -> AbstractConcept:
	var viewport := _get_subviewport()
	if not viewport:
		return null
	for child in viewport.get_children():
		if child is AbstractConcept and child.imaginary_tag == ima:
			return child
	return null


func _direct_merge(ima: ImaginaryConcept) -> void:
	ImaginaryComprehender.merge_category(ima.uuid)
	EventBus.imaginary_changed.emit()
	_rebuild_subviewport()


func on_merge_animation_finished(ima: ImaginaryConcept) -> void:
	Logging.info('PoemCrafter: merge animation finished for: %s' % ima.name)
	_direct_merge(ima)


func on_slot_clicked(slot: PoemSlot) -> void:
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()
	var slot_index := slots.find(slot)

	if slot_index == -1 or slot_index >= selected_imaginaries.size():
		return

	Logging.info('PoemCrafter: removing concept at slot %d' % slot_index)
	selected_imaginaries.remove_at(slot_index)
	render_slots()

	if selected_imaginaries.size() < 3:
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = ""
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "代价是..."

	_rebuild_subviewport()


# ──────────────────────────────────────────────
# 诗词创作
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	if selected_imaginaries.size() != 3:
		Logging.warn('PoemCrafter: need exactly 3 concepts, have %d' % selected_imaginaries.size())
		return

	Logging.info('PoemCrafter: crafting poem with poem_type=%d' % selected_poem_type)

	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, selected_poem_type)
	Logging.info('PoemCrafter: grade calculated, passed=%s, secular=%f, literary=%f' %
		[result.passed, result.secular_value, result.literary_value])

	if not result.passed:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = result.penalty_text
		Logging.info('PoemCrafter: poem creation failed, reason=%s' % result.fail_reason)
		if result.fail_reason == "fragment":
			# 惩罚但不消耗意象
			return
		return

	result.operate()

	# 创建 Poem trait 并注册
	var poem = Poem.new("POEM", ENUMS.POEM_TYPE.keys()[selected_poem_type], result.poem_level, result.secular_value, result.literary_value)
	poem.uuid = "crafted_poem_%s_%d" % [ENUMS.POEM_TYPE.keys()[selected_poem_type], Time.get_unix_time_from_system()]
	poem.name = "《%s》" % ENUMS.POEM_TYPE.keys()[selected_poem_type]
	poem.specific_topic = ENUMS.POEM_TYPE.keys()[selected_poem_type]

	# 注册到 Database（内存态）以便 PlayerState.add_trait 能通过 Database.get_trait 找到
	Database.traits[poem.uuid] = poem
	PlayerState.add_trait(poem.uuid)
	Logging.info('PoemCrafter: Poem trait created and added: %s' % poem.uuid)

	# 消耗 concepts
	ImaginaryComprehender.consume_concepts(selected_imaginaries)

	# 扫描诗词事件
	Logging.info('PoemCrafter: scanning for poem events')
	for ima in selected_imaginaries:
		for detail_imag in ImaginaryComprehender.get_imaginaries_for_concept(ima.uuid):
			for tag in detail_imag.detail_imaginaries:
				if not tag.is_empty():
					PlayerState.current_action_tags.append(tag)

	EventManager.scan_poem_events(selected_imaginaries)

	# 推送诗词揭示事件
	var ctx = {
		"poem_secular": result.secular_value,
		"poem_literary": result.literary_value,
		"poem_type": poem.specific_topic,
		"poem_level": result.poem_level,
	}
	EventBus.push_event.emit("poem_reveal", ctx)
	Logging.info('PoemCrafter: poem reveal event pushed')

	selected_imaginaries.clear()
	render_slots()
	_rebuild_subviewport()


# ──────────────────────────────────────────────
# 拒写机制
# ──────────────────────────────────────────────

func _on_tear_scroll_pressed() -> void:
	Logging.info('PoemCrafter: 撕毁卷轴 — 拒写')

	var amounts = NamedDSLParser._load_named_amounts()
	var loss = amounts.get("s_literary_fame_loss", -10)
	PlayerState.append_stat("literary_fame", loss)
	Logging.info('PoemCrafter: 扣除 literary_fame %d' % loss)

	EventBus.poem_cancel.emit()


# ──────────────────────────────────────────────
# 辅助
# ──────────────────────────────────────────────

func _get_subviewport() -> SubViewport:
	return $Panel/VBoxContainer/HBoxContainer/SubViewportContainer/SubViewport as SubViewport


func render_slots() -> void:
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()
	for i in range(slots.size()):
		if slots[i] is PoemSlot:
			var slot := slots[i] as PoemSlot
			if i < selected_imaginaries.size():
				slot.set_tag(selected_imaginaries[i])
			else:
				slot.clear()


# ──────────────────────────────────────────────
# 浮现/退出动画
# ──────────────────────────────────────────────

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
