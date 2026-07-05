extends PanelContainer

## 诗词创作面板 — V8: 动态 Slot + 模式切换 + C(N,3) 组合枚举
##
## V8 变更:
##   - PoemSlot 变为纯展示，不再可点击选择
##   - 从 Database.imaginaries_detail 自动获取所有 Imaginary 作为创作素材
##   - dynamically 创建 PoemSlot，超过 max_imaginary_managable 随机截断 + "过多…" 占位
##   - Toggle 按钮（登高抒怀/干谒权贵）决定 mode，覆盖 channel 乘数
##   - 删除 ImaginaryList / selected_imaginaries 手动选择逻辑
##   - Calculator 内部枚举 C(N,3) 组合匹配食谱

## 当前选中的 toggle mode: "deng_gao" | "gan_ye"
var current_mode: String = "gan_ye"

## Slot 容器路径
const SLOTS_PARENT_PATH := "Panel/InputImagPanel/H"

## PoemSlot packed scene
const POEM_SLOT_SCENE := preload("res://ui/poem_slot.tscn")


func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter V8')

	EventBus.imaginary_changed.connect(on_imaginary_changed)

	# "开始创作"按钮
	var craft_btn := $Panel/InputImagPanel/CraftBtn
	if craft_btn:
		craft_btn.pressed.connect(_on_button_pressed)
		Logging.info('PoemCrafter: CraftBtn.pressed 连接成功')

	# "撕毁卷轴"按钮
	var tear_btn := $Panel/Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	# Toggle 按钮：监听 button_group 变更
	_connect_toggle_signals()

	call_deferred("_rebuild_slots")


# ──────────────────────────────────────────────
# Toggle 模式管理
# ──────────────────────────────────────────────

func _connect_toggle_signals() -> void:
	var btn_deng_gao := $Panel/InputImagPanel/VBoxContainer2/Button2
	var btn_gan_ye := $Panel/InputImagPanel/VBoxContainer2/Button

	if btn_deng_gao:
		btn_deng_gao.toggled.connect(_on_toggle_deng_gao)
		Logging.info('PoemCrafter: 登高抒怀 toggle 连接成功')
	if btn_gan_ye:
		btn_gan_ye.toggled.connect(_on_toggle_gan_ye)
		Logging.info('PoemCrafter: 干谒权贵 toggle 连接成功')

	# 初始化 mode：读取当前 button_group 中被按下的按钮
	if btn_gan_ye and btn_gan_ye.button_pressed:
		current_mode = "gan_ye"
	elif btn_deng_gao and btn_deng_gao.button_pressed:
		current_mode = "deng_gao"
	Logging.info('PoemCrafter: initial mode = %s' % current_mode)


func _on_toggle_deng_gao(pressed: bool) -> void:
	if pressed:
		current_mode = "deng_gao"
		Logging.info('PoemCrafter: mode → deng_gao (BROADCAST 管道)')
		_preview_current()


func _on_toggle_gan_ye(pressed: bool) -> void:
	if pressed:
		current_mode = "gan_ye"
		Logging.info('PoemCrafter: mode → gan_ye (SECULAR 管道)')
		_preview_current()


# ──────────────────────────────────────────────
# Slot 动态构建
# ──────────────────────────────────────────────

func _rebuild_slots() -> void:
	var h_container := get_node_or_null(SLOTS_PARENT_PATH)
	if not h_container:
		Logging.err('PoemCrafter: Slot 容器 %s 不存在' % SLOTS_PARENT_PATH)
		return

	# 清空旧 Slot
	for child in h_container.get_children():
		child.queue_free()

	var all_imaginaries: Array[Imaginary] = []
	for imag in Database.imaginaries_detail.values():
		if imag is Imaginary:
			all_imaginaries.append(imag)

	Logging.info('PoemCrafter: _rebuild_slots — 总 Imaginary 数: %d' % all_imaginaries.size())

	if all_imaginaries.is_empty():
		var label := Label.new()
		label.text = "暂无意象"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		h_container.add_child(label)
		return

	var max_visible: int = PlayerState.max_imaginary_managable
	var display_list: Array[Imaginary] = []
	var has_overflow: bool = false

	if all_imaginaries.size() <= max_visible:
		display_list = all_imaginaries
		Logging.info('PoemCrafter: 全部展示 %d 个 Imaginary' % display_list.size())
	else:
		# 随机截断
		all_imaginaries.shuffle()
		for i in range(max_visible):
			display_list.append(all_imaginaries[i])
		has_overflow = true
		Logging.info('PoemCrafter: 随机截断 %d/%d 个 Imaginary，溢出=%s' % [max_visible, all_imaginaries.size(), has_overflow])

	# 创建 PoemSlot
	for imag in display_list:
		var slot := _create_slot(imag.name, false)
		slot.item_occupying = imag
		h_container.add_child(slot)

	# 溢出 Slot
	if has_overflow:
		var overflow_slot := _create_slot("过多…", true)
		overflow_slot.item_occupying = null
		h_container.add_child(overflow_slot)
		Logging.info('PoemCrafter: 添加溢出 Slot "过多…"')

	# 自动预览
	_preview_current()


func _create_slot(text: String, greyed: bool) -> PoemSlot:
	var slot: PoemSlot = POEM_SLOT_SCENE.instantiate()
	slot.apply_text(text)
	if greyed:
		slot.set_greyed(true)
	return slot


# ──────────────────────────────────────────────
# 事件监听
# ──────────────────────────────────────────────

func on_imaginary_changed() -> void:
	Logging.info('PoemCrafter: imaginary_changed 信号，重建 Slot')
	_rebuild_slots()


# ──────────────────────────────────────────────
# 获取当前所有有效 Imaginary（排除溢出占位）
# ──────────────────────────────────────────────

func _get_all_valid_imaginaries() -> Array[Imaginary]:
	var all: Array[Imaginary] = []
	for imag in Database.imaginaries_detail.values():
		if imag is Imaginary:
			all.append(imag)
	return all


# ──────────────────────────────────────────────
# 诗词创作 V8
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	var all_imaginaries := _get_all_valid_imaginaries()

	if all_imaginaries.size() < 3:
		Logging.warn('PoemCrafter: 需要至少 3 个 Imaginary，当前 %d' % all_imaginaries.size())
		$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]意象不足，至少需要三个意象方能成诗。[/color]"
		return

	# 上限检查
	if _has_unused_poem():
		Logging.warn('PoemCrafter: 已有未使用的诗词，拒绝创作')
		$Panel/InputImagPanel/RichTextLabel.text = "已有诗作，先将其送出或题壁后再来。"
		return

	Logging.info('PoemCrafter: crafting poem V8 — %d imaginaries, mode=%s' % [all_imaginaries.size(), current_mode])

	var result := PoemCraftingCalculator.calculate_poem_grade(all_imaginaries, Database.recipe_index, current_mode)
	Logging.info('PoemCrafter: grade calculated, passed=%s, combos=%d, secular=%f, literary=%f' %
		[result.passed, result.tried_combinations, result.secular_value, result.literary_value])

	# ── 失败（消耗匹配的 3 个 Imaginary，无匹配则不消耗）──
	if not result.passed:
		$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]你沉吟良久，终究觉得这些意象散落四处，凑不成章。[/color]\n[color=#888]不如再寻些贴合的意象来…[/color]"
		Logging.info('PoemCrafter: poem creation failed, reason=%s, combos tried=%d' % [result.fail_reason, result.tried_combinations])
		# 不消耗 — 无匹配时保留所有 Imaginary
		_rebuild_slots()
		return

	# ── 匹配成功 ──
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

	# 仅消耗匹配命中的 3 个 Imaginary
	_consume_matched_imaginaries(result.matched_imaginary_uuids)

	_rebuild_slots()


func _consume_matched_imaginaries(uuids: Array[String]) -> void:
	Logging.info('PoemCrafter: 消耗命中的 3 个 Imaginary: %s' % str(uuids))
	for uuid in uuids:
		var key = uuid.to_lower()
		if Database.imaginaries_detail.has(key):
			Database.imaginaries_detail.erase(key)
			Logging.info('PoemCrafter: 消耗 Imaginary "%s"' % key)
		else:
			Logging.warn('PoemCrafter: 尝试消耗不存在的 Imaginary "%s"' % key)
	Logging.info('PoemCrafter: 消耗完成，剩余 %d 个 Imaginary' % Database.imaginaries_detail.size())


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
# V8 匹配预览（使用当前所有 Imaginary + current_mode）
# ──────────────────────────────────────────────

func _preview_current() -> void:
	var all_imaginaries := _get_all_valid_imaginaries()
	if all_imaginaries.size() < 3:
		$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]意象不足，至少需要三个意象方能成诗。[/color]"
		return

	var result := PoemCraftingCalculator.calculate_poem_grade(all_imaginaries, Database.recipe_index, current_mode)

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

		$Panel/InputImagPanel/RichTextLabel.text = "\n".join(lines)
		return

	$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]你将这%s个意象放在一处，有些疑惑——它们真的能凑成一首诗么？[/color]" % all_imaginaries.size()


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
