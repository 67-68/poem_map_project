extends PanelContainer

## 诗词创作面板 — V7: 扁平化意象系统，简单列表选择
##
## V7 变更: ImaginaryConcept 已删除。selected_imaginaries 改为 Array[Imaginary]。
## 删除 SubViewport/AbstractConcept/OrbitDetail/合并坍缩/Tier/打油诗。
## 用户从已拥有的 Imaginary 列表中点击选择 3 个，然后创作。

## 当前选中用于创作诗词的 Imaginary（最多 3 个）
var selected_imaginaries: Array[Imaginary] = []

## Imaginary 列表容器节点路径
const IMAGINARY_LIST_PATH := "Panel/VBoxContainer/HBoxContainer/ImaginaryList"


func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter V7')

	EventBus.imaginary_changed.connect(on_imaginary_changed)

	# 连接 PoemSlot 的点击信号
	var children = $Panel/VBoxContainer/InputImagPanel/H.get_children()
	Logging.info('PoemCrafter: connecting slot_clicked signals for %d children' % children.size())
	for c in children:
		if c.has_signal("slot_clicked"):
			c.slot_clicked.connect(on_slot_clicked)

	# "开始创作"按钮
	var craft_btn := $Panel/VBoxContainer/InputImagPanel/CraftBtn
	if craft_btn:
		craft_btn.pressed.connect(_on_button_pressed)
		Logging.info('PoemCrafter: CraftBtn.pressed 手动连接成功')

	# "撕毁卷轴"按钮
	var tear_btn := $Panel/Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	call_deferred("_rebuild_imaginary_list")


# ──────────────────────────────────────────────
# Imaginary 列表构建
# ──────────────────────────────────────────────

func _rebuild_imaginary_list() -> void:
	var list_container := get_node_or_null(IMAGINARY_LIST_PATH)
	if not list_container:
		Logging.warn('PoemCrafter: ImaginaryList container not found at %s' % IMAGINARY_LIST_PATH)
		return

	# 清空
	for child in list_container.get_children():
		child.queue_free()

	var imaginaries: Array[Imaginary] = []
	for imag in Database.imaginaries_detail.values():
		if imag is Imaginary and not selected_imaginaries.has(imag):
			imaginaries.append(imag)

	Logging.info('PoemCrafter: building imaginary list with %d available (total=%d)' % [imaginaries.size(), Database.imaginaries_detail.size()])

	for imag in imaginaries:
		var btn := Button.new()
		btn.text = imag.name
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_imaginary_button_pressed.bind(imag))
		list_container.add_child(btn)

	if imaginaries.is_empty():
		var label := Label.new()
		label.text = "暂无可用意象"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list_container.add_child(label)


func _on_imaginary_button_pressed(imag: Imaginary) -> void:
	Logging.info('PoemCrafter: imaginary button pressed: %s' % imag.name)

	if selected_imaginaries.size() >= 3:
		Logging.info('PoemCrafter: max 3 imaginaries reached')
		return

	selected_imaginaries.append(imag)
	render_slots()
	_rebuild_imaginary_list()

	if selected_imaginaries.size() == 3:
		Logging.info('PoemCrafter: 3 imaginaries selected, previewing match')
		_preview_match()


# ──────────────────────────────────────────────
# 事件监听
# ──────────────────────────────────────────────

func on_imaginary_changed() -> void:
	Logging.info('PoemCrafter: imaginary_changed signaled, rebuilding list')
	_rebuild_imaginary_list()


# ──────────────────────────────────────────────
# Slot 管理
# ──────────────────────────────────────────────

func on_slot_clicked(slot: PoemSlot) -> void:
	var slots := $Panel/VBoxContainer/InputImagPanel/H.get_children()
	var slot_index := slots.find(slot)

	if slot_index == -1 or slot_index >= selected_imaginaries.size():
		return

	Logging.info('PoemCrafter: removing imaginary at slot %d' % slot_index)
	selected_imaginaries.remove_at(slot_index)
	render_slots()

	if selected_imaginaries.size() < 3:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "代价是..."

	_rebuild_imaginary_list()


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
# 诗词创作 V7
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	if selected_imaginaries.size() != 3:
		Logging.warn('PoemCrafter: need exactly 3 imaginaries, have %d' % selected_imaginaries.size())
		return

	# 上限检查
	if _has_unused_poem():
		Logging.warn('PoemCrafter: 已有未使用的诗词，拒绝创作')
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "已有诗作，先将其送出或题壁后再来。"
		return

	Logging.info('PoemCrafter: crafting poem V7 — exact imaginary uuid match')

	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, Database.recipe_index)
	Logging.info('PoemCrafter: grade calculated, passed=%s, secular=%f, literary=%f' %
		[result.passed, result.secular_value, result.literary_value])

	# ── 失败（消耗 3 个 Imaginary）──
	if not result.passed:
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "[color=#aaa]你沉吟良久，终究觉得这些意象散落四处，凑不成章。[/color]\n[color=#888]不如再寻些贴合的意象来…[/color]"
		Logging.info('PoemCrafter: poem creation failed, reason=%s — consuming imaginaries' % result.fail_reason)
		ImaginaryComprehender.consume_imaginaries(selected_imaginaries)
		selected_imaginaries.clear()
		render_slots()
		_rebuild_imaginary_list()
		return

	# ── 精确匹配成功 ──
	_apply_operators(result.operators)

	var recipe = result.matched_recipe
	var poem_type_str = recipe.specific_topic if recipe else "GAN_YE"
	var poem = Poem.new("POEM", poem_type_str, result.secular_value, result.literary_value)
	poem.uuid = "crafted_poem_%s_%d" % [poem_type_str, Time.get_unix_time_from_system()]
	poem.name = recipe.name if recipe else "《%s》" % poem_type_str
	poem.specific_topic = poem_type_str

	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter: Poem created and added to created_poems: %s (%s)' % [poem.uuid, poem.name])

	var ctx = {
		"poem_secular": result.secular_value,
		"poem_literary": result.literary_value,
		"poem_type": poem.specific_topic,
	}
	EventBus.push_event.emit("poem_reveal", ctx)
	Logging.info('PoemCrafter: poem reveal event pushed')

	ImaginaryComprehender.consume_imaginaries(selected_imaginaries)

	selected_imaginaries.clear()
	render_slots()
	_rebuild_imaginary_list()


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


func _apply_operators(ops: Array) -> void:
	for op in ops:
		if op and op.has_method("execute"):
			op.execute()
		elif op and op.has_method("operate"):
			op.operate()


# ──────────────────────────────────────────────
# V7 匹配预览
# ──────────────────────────────────────────────

func _preview_match() -> void:
	var result := PoemCraftingCalculator.calculate_poem_grade(selected_imaginaries, Database.recipe_index)

	if result.passed:
		var recipe_name = result.matched_recipe.name if result.matched_recipe else "未知"
		var secular_text := _get_value_perception("secular", result.secular_value)
		var literary_text := _get_value_perception("literary", result.literary_value)
		var op_text := PoemCraftingCalculator.translate(result.operators)

		var lines: Array[String] = []
		lines.append("[color=gold]食谱: %s[/color]" % recipe_name)
		if not secular_text.is_empty():
			lines.append("[color=#daa520]世俗影响：%s[/color]" % secular_text)
		if not literary_text.is_empty():
			lines.append("[color=#87ceeb]文学价值：%s[/color]" % literary_text)
		if not op_text.is_empty():
			lines.append("")
			lines.append(op_text)

		$Panel/VBoxContainer/InputImagPanel/Button.tooltip_text = "\n".join(lines)
		$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "\n".join(lines)
		return

	$Panel/VBoxContainer/InputImagPanel/RichTextLabel.text = "[color=#aaa]你将这三者放在一处，有些疑惑——它们真的能凑成一首诗么？[/color]"


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
# 诗词价值感知
# ──────────────────────────────────────────────

static var _poem_perceptions_cache: Dictionary = {}

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
