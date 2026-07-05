extends PanelContainer

## 诗词创作面板 — V5: 精确 Set 匹配 + Tier 合并 + 打油诗
##
## 当前选中用于创作诗词的 ImaginaryConcept（最多 3 个）
var selected_imaginaries: Array[ImaginaryConcept] = []

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

## 品级名称映射（Tier 2/3 合并后仅 Tier 1 和 Tier 2）
const TIER_NAMES := {
	1: "世俗",
	2: "诗史"
}


func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter V5')

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

	# V5: poem_type 按钮不再连接逻辑（全类型盲搜），保留纯展示

	# "开始创作"按钮 — 手动连接（按钮已重命名为 CraftBtn，不再依赖命名约定）
	var craft_btn := $Panel/VBoxContainer/InputImagPanel/CraftBtn
	if craft_btn:
		craft_btn.pressed.connect(_on_button_pressed)
		Logging.info('PoemCrafter: CraftBtn.pressed 手动连接成功')

	# "撕毁卷轴"按钮 — 位于 $Panel/Button，手动连接
	var tear_btn := $Panel/Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	call_deferred("_rebuild_subviewport")
	call_deferred("_init_camera")
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
# SubViewport 排布算法 — V5 动态推导版
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

		Logging.info('PoemCrafter: placing concept "%s" (key=%s, fragments=%d, tier=%d)' %
			[concept.name, concept_key, fragment_count, concept.current_tier])

		var node := _ABSTRACT_CONCEPT_SCENE.instantiate() as AbstractConcept
		node.concept_name = concept.name
		node.imaginary_tag = concept

		node.concept_selected.connect(on_concept_selected)
		node.concept_merge_requested.connect(on_concept_merge_requested)
		node.merge_animation_finished.connect(on_merge_animation_finished)

		# V5: Tier >= 2 统一为 Tier 2 颜色
		var display_tier = concept.current_tier
		if display_tier >= 2:
			display_tier = 2
		if display_tier > 0:
			node.modulate = AbstractConcept.TIER_COLORS.get(display_tier, Color.WHITE)

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

		# 显示总碎片数
		var info_label := Label.new()
		info_label.text = "碎片: %d" % fragment_count
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
		Logging.info('PoemCrafter: 3 concepts selected, previewing match')
		_preview_match()


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
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = ""
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "代价是..."

	_rebuild_subviewport()


# ──────────────────────────────────────────────
# 诗词创作 V5
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	if selected_imaginaries.size() != 3:
		Logging.warn('PoemCrafter: need exactly 3 concepts, have %d' % selected_imaginaries.size())
		return

	# V5: 上限检查 — 移至按钮点击时
	if _has_unused_poem():
		Logging.warn('PoemCrafter: 已有未使用的诗词，拒绝创作')
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "已有诗作，先将其送出或题壁后再来。"
		return

	Logging.info('PoemCrafter: crafting poem V5 — full blind search')

	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, Database.recipe_index)
	Logging.info('PoemCrafter: grade calculated, passed=%s, is_doggerel=%s, secular=%f, literary=%f' %
		[result.passed, result.is_doggerel, result.secular_value, result.literary_value])

	# ── 打油诗 ──
	if result.is_doggerel:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = result.penalty_text
		Logging.info('PoemCrafter: 打油诗 — literary_fame +%.0f' % result.literary_value)
		_apply_operators(result.operators)
		ImaginaryComprehender.consume_concepts(selected_imaginaries)
		selected_imaginaries.clear()
		render_slots()
		_rebuild_subviewport()
		EventBus.request_float_text.emit("🪶 意象未全，凑成一首打油诗", {"color": Color(0.976, 0.792, 0.141)})
		return

	# ── 失败（消耗意象，但不产出诗词）──
	if not result.passed:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "[color=#aaa]你沉吟良久，终究觉得这些意象散落四处，凑不成章。[/color]\n[color=#888]不如再寻些贴合的意象来…[/color]"
		Logging.info('PoemCrafter: poem creation failed, reason=%s — consuming concepts' % result.fail_reason)
		ImaginaryComprehender.consume_concepts(selected_imaginaries)
		selected_imaginaries.clear()
		render_slots()
		_rebuild_subviewport()
		return

	# ── 精确匹配成功 ──
	_apply_operators(result.operators)

	# 创建 Poem trait 并注册
	var recipe = result.matched_recipe
	var poem_type_str = recipe.specific_topic if recipe else "GAN_YE"
	var poem = Poem.new("POEM", poem_type_str, result.secular_value, result.literary_value)
	poem.uuid = "crafted_poem_%s_%d" % [poem_type_str, Time.get_unix_time_from_system()]
	poem.name = recipe.name if recipe else "《%s》" % poem_type_str
	poem.specific_topic = poem_type_str

	# V5: 使用 created_poems 而非 trait 管道
	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter: Poem created and added to created_poems: %s (%s)' % [poem.uuid, poem.name])

	# 推送诗词揭示事件（不扫描普通诗词事件，直接展示创作结果）
	var ctx = {
		"poem_secular": result.secular_value,
		"poem_literary": result.literary_value,
		"poem_type": poem.specific_topic,
	}
	EventBus.push_event.emit("poem_reveal", ctx)
	Logging.info('PoemCrafter: poem reveal event pushed')

	# 消耗 concepts（放在事件扫描之后，因为扫描需要读取 fragments）
	ImaginaryComprehender.consume_concepts(selected_imaginaries)

	selected_imaginaries.clear()
	render_slots()
	_rebuild_subviewport()


## 检查是否已有未使用的诗词（上限检查）
## 同时检查旧 trait 管道和新 created_poems 管道（pending poem_refactor_detrait）
func _has_unused_poem() -> bool:
	for entry in PlayerState.created_poems:
		if entry is Poem and entry.topic == "POEM":
			return true
	for trait_uuid in PlayerState.traits:
		var t = Database.get_trait(trait_uuid)
		if t != null and t is Poem and t.topic == "POEM" and t.uuid.begins_with("poem_recipe_"):
			Logging.info('PoemCrafter: 检测到已有诗词 trait: %s (%s)' % [t.name, t.uuid])
			return true
	return false


## 应用算子列表
func _apply_operators(ops: Array) -> void:
	for op in ops:
		if op and op.has_method("execute"):
			op.execute()
		elif op and op.has_method("operate"):
			op.operate()


# ──────────────────────────────────────────────
# V5 匹配预览
# ──────────────────────────────────────────────

func _preview_match() -> void:
	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, Database.recipe_index)

	if result.is_doggerel:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "[color=#f9ca24]🪶 打油诗[/color]\n意象未全，literary_fame +5"
		return

	if result.passed:
		# 精确匹配 → 显示品级预览
		var text := _build_barrel_preview(result)
		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = text
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = text
		return

	# 无匹配 → 显示 Tier/Level 估计，而非直接报失败
	var estimate := _build_tier_estimate()
	$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = estimate


## 无食谱匹配时，基于 Tier+Level 给出叙事化估评
func _build_tier_estimate() -> String:
	var min_tier := 999
	for c in selected_imaginaries:
		if c is ImaginaryConcept:
			if c.current_tier > 0:
				min_tier = mini(min_tier, c.current_tier)
	if min_tier >= 2:
		min_tier = 2
	if min_tier == 999:
		min_tier = 1

	var tier_name = TIER_NAMES.get(min_tier, "未知")
	var lines: Array[String] = []
	lines.append("[color=#aaa]你将这三者放在一处，有些疑惑——[/color]")
	lines.append("[color=#ccc]它们真的能凑成一首诗么？[/color]")
	lines.append("")
	lines.append("[color=#888]品级约 T%d · %s[/color]" % [min_tier, tier_name])
	return "\n".join(lines)


## 找出所有 tier == min_tier 的概念（木桶的短板）
func _find_weakest_concepts(min_tier: int) -> Array[ImaginaryConcept]:
	var weakest: Array[ImaginaryConcept] = []
	for c in selected_imaginaries:
		var display_tier = c.current_tier
		if display_tier >= 2:
			display_tier = 2
		if display_tier == min_tier:
			weakest.append(c)
	return weakest


## 生成木桶效应 + 收益组合的人类可读预览文本
func _build_barrel_preview(result: PoemCraftingCalculator.PoemCraftingResult) -> String:
	var lines: Array[String] = []

	var tier_name = TIER_NAMES.get(result.min_tier, "未知")
	var recipe_name = result.matched_recipe.name if result.matched_recipe else "未知"
	lines.append("[color=gold]品级 T%d · %s[/color]" % [result.min_tier, tier_name])
	lines.append("[color=#ccc]食谱: %s[/color]" % recipe_name)

	var weakest = _find_weakest_concepts(result.min_tier)
	var higher: Array[ImaginaryConcept] = []
	for c in selected_imaginaries:
		var display_tier = c.current_tier
		if display_tier >= 2:
			display_tier = 2
		if display_tier > result.min_tier:
			higher.append(c)

	if not higher.is_empty():
		var weak_names = "、".join(weakest.map(func(c): return "「%s」" % c.name))
		var high_names = "、".join(higher.map(func(c): return "「%s」" % c.name))
		lines.append("%s 的格调被 %s 拖累，%s 蒙尘降格" % [high_names, weak_names, high_names])

	# 世俗/文学价值 stage perception
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
	
	var center := vsize / 2.0
	_camera.position.x = clampf(_camera.position.x, center.x - vsize.x, center.x + vsize.x)
	_camera.position.y = clampf(_camera.position.y, center.y - vsize.y, center.y + vsize.y)


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
