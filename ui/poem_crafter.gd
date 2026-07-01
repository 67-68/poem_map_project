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

## Camera2D 引用（用于 WASD 平移 SubViewport 视角）
var _camera: Camera2D = null

## WASD 相机移动速度（px/s）
const CAMERA_SPEED := 300.0

## 品级名称映射（来自 imagery_tier_synthesis_poem_engine.md 第 1.2 节）
const TIER_NAMES := {
	1: "世俗",
	2: "诗史",
	3: "绝唱"
}


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

	# "开始创作"按钮 — 手动连接（节点已重命名为 CraftBtn 以避免与 POEM TYPE toggle 重名冲突）
	var craft_btn := $Panel/VBoxContainer/InputImagPanel/CraftBtn
	if craft_btn:
		craft_btn.pressed.connect(_on_button_pressed)
		Logging.info('PoemCrafter: CraftBtn.pressed signal connected')
	# "撕毁卷轴"按钮 — 位于 $Panel/Button，手动连接
	var tear_btn := $Panel/Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	call_deferred("_rebuild_subviewport")
	call_deferred("_init_camera")


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
			var frags = ImaginaryComprehender.get_imaginaries_for_concept(collider.imaginary_tag.uuid)
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					AudioManager.play_sfx_category("leather")
					if frags.size() == 1:
						on_concept_merge_requested(collider.imaginary_tag)
					else:
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

		# 为每个关联的 Imaginary 创建轨道碎片（OrbitDetail）
		for j in range(detail_imaginaries.size()):
			var frag_imag: Imaginary = detail_imaginaries[j]
			var orbit := _DETAIL_IMAGINARY_SCENE.instantiate() as OrbitDetail
			orbit.center_target = node
			orbit.semi_major_axis = 60.0 + j * 5.0
			orbit.semi_minor_axis = 45.0 + j * 3.0
			orbit.orbit_speed = 0.8 + j * 0.15
			orbit.phase_offset = j * PI / 3.0
			orbit.set_detail_text(frag_imag.name)
			node.add_child(orbit)

		# 显示总碎片数 + Level
		var info_label := Label.new()
		info_label.text = "碎片: %d | Lv.%d" % [fragment_count, concept.current_level]
		info_label.add_theme_font_size_override("font_size", 10)
		info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.position = Vector2(-40, 40)
		info_label.size = Vector2(80, 16)
		node.add_child(info_label)

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
			var text := _build_barrel_preview(result)
			$Panel/VBoxContainer/InputImagPanel/CraftBtn.tooltip_text = text
			$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = text
		else:
			$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = result.penalty_text


func on_concept_merge_requested(ima: ImaginaryConcept) -> void:
	Logging.info('PoemCrafter: merge requested for concept: %s' % ima.name)

	if selected_imaginaries.has(ima):
		Logging.warn('PoemCrafter: concept already selected, cannot merge')
		return

	if not ImaginaryComprehender.can_merge(ima.uuid):
		Logging.warn('PoemCrafter: merge precondition failed for: %s (need ≥1 fragment)' % ima.name)
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
		$Panel/VBoxContainer/InputImagPanel/CraftBtn.tooltip_text = ""
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

	# 执行 operators（PoemCraftingResult 是纯数据类，不含 operate()）
	for op in result.operators:
		if op and op.has_method("operate"):
			op.operate()

	# 创建 Poem trait 并注册
	var poem = Poem.new("POEM", ENUMS.POEM_TYPE.keys()[selected_poem_type], result.poem_level, result.secular_value, result.literary_value)
	poem.uuid = "crafted_poem_%s_%d" % [ENUMS.POEM_TYPE.keys()[selected_poem_type], Time.get_unix_time_from_system()]
	poem.name = "《%s》" % ENUMS.POEM_TYPE.keys()[selected_poem_type]
	poem.specific_topic = ENUMS.POEM_TYPE.keys()[selected_poem_type]

	# 注册到 Database（内存态）以便 PlayerState.add_trait 能通过 Database.get_trait 找到
	Database.traits[poem.uuid] = poem
	PlayerState.add_trait(poem.uuid)
	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter: Poem trait created and added: %s, created_poems count: %d' % [poem.uuid, PlayerState.created_poems.size()])

	# 消耗 concepts
	ImaginaryComprehender.consume_concepts(selected_imaginaries)

	# 扫描诗词事件
	Logging.info('PoemCrafter: scanning for poem events')
	for ima in selected_imaginaries:
		for detail_imag in ImaginaryComprehender.get_imaginaries_for_concept(ima.uuid):
			for concept_key in detail_imag.concepts:
				if not concept_key.is_empty():
					PlayerState.current_action_tags.append(concept_key)

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
# Camera2D 初始化和 WASD 移动
# ──────────────────────────────────────────────

func _init_camera() -> void:
	var vp := _get_subviewport()
	if not vp:
		Logging.warn("PoemCrafter: _init_camera — SubViewport not found")
		return
	_camera = vp.get_node_or_null("Camera2D") as Camera2D
	if _camera:
		_camera.position = vp.size / 2.0
		Logging.info("PoemCrafter: Camera2D initialized at %s" % _camera.position)
	else:
		Logging.warn("PoemCrafter: Camera2D node not found in SubViewport")


func _process(delta: float) -> void:
	if not visible or not _camera:
		return
	
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	
	if dir == Vector2.ZERO:
		return
	
	var vp := _get_subviewport()
	if not vp:
		return
	var vsize := vp.size
	var move := dir.normalized() * CAMERA_SPEED * delta
	_camera.position += move
	
	# 边界限制：允许偏离中心 ±vsize
	var center := vsize / 2.0
	_camera.position.x = clampf(_camera.position.x, center.x - vsize.x, center.x + vsize.x)
	_camera.position.y = clampf(_camera.position.y, center.y - vsize.y, center.y + vsize.y)


# ──────────────────────────────────────────────
# 木桶效应预览
# ──────────────────────────────────────────────

## 找出所有 tier == min_tier 的概念（木桶的短板）
func _find_weakest_concepts(min_tier: int) -> Array[ImaginaryConcept]:
	var weakest: Array[ImaginaryConcept] = []
	for c in selected_imaginaries:
		if c.current_tier == min_tier:
			weakest.append(c)
	return weakest


## 生成木桶效应 + 收益组合的人类可读预览文本
func _build_barrel_preview(result: PoemCraftingCalculator.PoemCraftingResult) -> String:
	var lines: Array[String] = []
	
	var tier_name = TIER_NAMES.get(result.min_tier, "未知")
	lines.append("[color=gold]品级 T%d · %s[/color]" % [result.min_tier, tier_name])
	
	var weakest = _find_weakest_concepts(result.min_tier)
	var higher: Array[ImaginaryConcept] = []
	for c in selected_imaginaries:
		if c.current_tier > result.min_tier:
			higher.append(c)
	
	if not higher.is_empty():
		var weak_names = "、".join(weakest.map(func(c): return "「%s」" % c.name))
		var high_names = "、".join(higher.map(func(c): return "「%s」" % c.name))
		lines.append("%s 的格调被 %s 拖累，%s 蒙尘降格" % [high_names, weak_names, high_names])
	
	# 世俗/文学价值 stage perception（复用 property 的 change_perceptions 配置）
	var secular_text := _get_value_perception("secular", result.secular_value)
	var literary_text := _get_value_perception("literary", result.literary_value)
	
	if not secular_text.is_empty():
		lines.append("[color=#daa520]世俗影响：%s[/color]" % secular_text)
	if not literary_text.is_empty():
		lines.append("[color=#87ceeb]文学价值：%s[/color]" % literary_text)
	
	var op_text := PoemCraftingCalculator.translate(result.operators)
	if not op_text.is_empty():
		lines.append("")
		lines.append(op_text)
	
	return "\n".join(lines)


## 获取属性变更量的 stage perception 文本（复用 property 的 change_perceptions 配置）
## 诗词价值感知 JSON 缓存
static var _poem_perceptions_cache: Dictionary = {}

## 加载诗词价值感知 JSON 配置（data/1_core_rules/poem_value_perceptions.json）
static func _load_poem_perceptions() -> Dictionary:
	if not _poem_perceptions_cache.is_empty():
		return _poem_perceptions_cache
	var path := "res://data/1_core_rules/poem_value_perceptions.json"
	if not FileAccess.file_exists(path):
		Logging.warn("PoemCrafter: poem_value_perceptions.json 不存在: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Logging.err("PoemCrafter: 无法打开 poem_value_perceptions.json")
		return {}
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		Logging.err("PoemCrafter: poem_value_perceptions.json 解析失败")
		return {}
	_poem_perceptions_cache = json.get_data()
	return _poem_perceptions_cache


## 根据诗词价值获取 stage perception 文本
## category: "secular" → 世俗影响, "literary" → 文学价值
func _get_value_perception(category: String, value: float) -> String:
	if value == 0:
		return ""
	var data := _load_poem_perceptions()
	var key := category + "_perceptions"
	var perceptions: Array = data.get(key, [])
	if perceptions.is_empty():
		return ""
	var abs_val: float = abs(value)
	var is_gain := value > 0
	# 从高到低遍历，首个 abs_val >= threshold 的条目生效
	for p in perceptions:
		var threshold: int = p.get("threshold", 0)
		if abs_val >= threshold:
			return p.get("gain_text" if is_gain else "loss_text", "")
	return ""
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
				slot.apply_text(selected_imaginaries[i].name)
				slot.item_occupying = selected_imaginaries[i]
			else:
				slot.apply_text("")
				slot.item_occupying = null


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
