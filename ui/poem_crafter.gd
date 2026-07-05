extends PanelContainer

## 诗词创作面板 — V9: 纯函数评分制 + 三级事件库抽奖
##
## V9 变更:
##   - 砍掉 C(N,3) 食谱枚举，替换为线性评分制
##   - 纯函数 PoemCraftingCalculator：禁止 randf/Database/PlayerState
##   - 概率升级抽奖由调用方执行，纯函数仅输出概率
##   - 三个等级的 EventBase 事件库（平庸/佳作/绝唱）
##   - mode 硬赋值 secular/literary（干谒→64/0，登高→0/48）
##   - 消耗全部参与计算的 Imaginary（不再仅消耗命中 3 个）

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
# 诗词创作 V9
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	var all_imaginaries := _get_all_valid_imaginaries()

	# ── 1. 纯函数计算 ──
	var max_manageable: int = PlayerState.max_imaginary_managable
	var result := PoemCraftingCalculator.calculate_poem_grade(all_imaginaries, current_mode, max_manageable)
	Logging.info('PoemCrafter(V9): calculate_poem_grade — passed=%s, fail_reason=%s, score=%d, base_level=%d, upgrade_prob=%.3f, secular=%.1f, literary=%.1f' %
		[result.passed, result.fail_reason, result.score, result.base_level, result.upgrade_probability, result.secular_value, result.literary_value])

	# ── 2. insufficient 校验 ──
	if not result.passed:
		if result.fail_reason == "insufficient":
			Logging.warn('PoemCrafter(V9): 意象不足 — 当前 %d, 需要至少 %d' % [all_imaginaries.size(), max_manageable])
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]意象不足，至少需要%d个意象方能成诗。[/color]" % max_manageable
		else:
			Logging.err('PoemCrafter(V9): 未知错误 — fail_reason=%s' % result.fail_reason)
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]出了些问题，稍后再试吧。[/color]"
		return

	# ── 3. 已有诗作上限检查 ──
	if _has_unused_poem():
		Logging.warn('PoemCrafter(V9): 已有未使用的诗词，拒绝创作')
		$Panel/InputImagPanel/RichTextLabel.text = "已有诗作，先将其送出或题壁后再来。"
		return

	Logging.info('PoemCrafter(V9): crafting poem — %d imaginaries, mode=%s, score=%d' % [all_imaginaries.size(), current_mode, result.score])

	# ── 4. 概率升级抽奖（调用方执行 randf，纯函数仅输出概率）──
	var final_level: int = result.base_level
	var upgrade_succeeded: bool = false
	if final_level < 3 and result.upgrade_probability > 0.0:
		var roll: float = randf()
		if roll < result.upgrade_probability:
			final_level += 1
			upgrade_succeeded = true
			Logging.info('PoemCrafter(V9): 概率升级成功！roll=%.3f < prob=%.3f → level=%d (%s)' % [roll, result.upgrade_probability, final_level, PoemCraftingCalculator.get_level_display_name(final_level)])
		else:
			Logging.info('PoemCrafter(V9): 概率升级失败 roll=%.3f >= prob=%.3f → level=%d (%s)' % [roll, result.upgrade_probability, final_level, PoemCraftingCalculator.get_level_display_name(final_level)])
	else:
		Logging.info('PoemCrafter(V9): 无需升级 — base_level=%d (%s), upgrade_prob=%.3f' % [final_level, PoemCraftingCalculator.get_level_display_name(final_level), result.upgrade_probability])

	# ── 5. 创建 Poem 对象 ──
	var level_display_name := PoemCraftingCalculator.get_level_display_name(final_level)
	var poem = Poem.new("POEM", level_display_name, result.secular_value, result.literary_value)
	poem.uuid = "crafted_poem_l%d_%d" % [final_level, Time.get_unix_time_from_system()]
	poem.name = "《%s》" % level_display_name
	poem.level = final_level
	poem.specific_topic = level_display_name
	Logging.info('PoemCrafter(V9): Poem created — uuid=%s, name=%s, level=%d' % [poem.uuid, poem.name, poem.level])

	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter(V9): Poem added to created_poems')

	# ── 6. 算子生成并执行 ──
	var operators: Array = []
	if result.secular_value != 0.0:
		operators.append(OperatorFactory.create_property_operator("money", result.secular_value))
		Logging.info('PoemCrafter(V9): 生成 money 算子: %.1f' % result.secular_value)
	if result.literary_value != 0.0:
		operators.append(OperatorFactory.create_property_operator("literary_fame", result.literary_value))
		Logging.info('PoemCrafter(V9): 生成 literary_fame 算子: %.1f' % result.literary_value)
	_apply_operators(operators)
	Logging.info('PoemCrafter(V9): 算子执行完成 — %d 个算子' % operators.size())

	# ── 7. 消耗所有参与计算的 Imaginary ──
	_consume_all_imaginaries()

	# ── 8. 从对应等级的 EventBase 抽取事件 ──
	var event_base_uuid := PoemCraftingCalculator.get_event_base_for_level(final_level)
	var ctx := {
		"poem_secular": result.secular_value,
		"poem_literary": result.literary_value,
		"poem_level": final_level,
		"poem_level_name": level_display_name,
	}
	Logging.info('PoemCrafter(V9): 从 EventBase 抽事件 — base=%s, ctx=%s' % [event_base_uuid, str(ctx)])

	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("draw_from_event_base"):
		var selected_uuid = event_manager.draw_from_event_base(event_base_uuid, ctx)
		if selected_uuid.is_empty():
			Logging.err('PoemCrafter(V9): EventBase 抽取失败，降级使用 push_event "poem_reveal"')
			EventBus.push_event.emit("poem_reveal", ctx)
		else:
			Logging.info('PoemCrafter(V9): EventBase 抽取成功 — selected=%s' % selected_uuid)
	else:
		Logging.err('PoemCrafter(V9): EventManager 或 draw_from_event_base 不存在，降级使用 push_event "poem_reveal"')
		EventBus.push_event.emit("poem_reveal", ctx)

	_rebuild_slots()


func _consume_matched_imaginaries(uuids: Array[String]) -> void:
	## V8 旧方法 — 仅消耗命中食谱的 3 个 Imaginary，V9 不再使用
	Logging.info('PoemCrafter: 消耗命中的 3 个 Imaginary: %s' % str(uuids))
	for uuid in uuids:
		var key = uuid.to_lower()
		if Database.imaginaries_detail.has(key):
			Database.imaginaries_detail.erase(key)
			Logging.info('PoemCrafter: 消耗 Imaginary "%s"' % key)
		else:
			Logging.warn('PoemCrafter: 尝试消耗不存在的 Imaginary "%s"' % key)
	Logging.info('PoemCrafter: 消耗完成，剩余 %d 个 Imaginary' % Database.imaginaries_detail.size())


## V9: 消耗所有参与计算的 Imaginary（全量清空）
func _consume_all_imaginaries() -> void:
	var count := Database.imaginaries_detail.size()
	Logging.info('PoemCrafter(V9): 消耗全部 %d 个 Imaginary' % count)
	Database.imaginaries_detail.clear()
	Logging.info('PoemCrafter(V9): 消耗完成，剩余 0 个 Imaginary')


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
# V9 匹配预览（使用当前所有 Imaginary + current_mode）
# ──────────────────────────────────────────────

func _preview_current() -> void:
	var all_imaginaries := _get_all_valid_imaginaries()
	var max_manageable: int = PlayerState.max_imaginary_managable
	
	var result := PoemCraftingCalculator.calculate_poem_grade(all_imaginaries, current_mode, max_manageable)

	# ── insufficient ──
	if not result.passed:
		if result.fail_reason == "insufficient":
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]意象不足，至少需要%d个意象方能成诗。[/color]" % max_manageable
		else:
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]出了些问题…[/color]"
		return

	# ── 成功：展示评分预览 ──
	var base_level_name := PoemCraftingCalculator.get_level_display_name(result.base_level)
	var upgrade_pct := int(result.upgrade_probability * 100)
	var mode_label := "干谒权贵" if current_mode == "gan_ye" else "登高抒怀"
	
	var lines: Array[String] = []
	lines.append("[color=#daa520]模式: %s[/color]" % mode_label)
	lines.append("[color=white]意象数: %d | 总分: %d[/color]" % [all_imaginaries.size(), result.score])
	lines.append("[color=#87ceeb]基础评级: %s[/color]" % base_level_name)
	
	if result.base_level < 3 and result.upgrade_probability > 0.0:
		var next_level_name := PoemCraftingCalculator.get_level_display_name(result.base_level + 1)
		lines.append("[color=gold]晋升 %s 概率: %d%%[/color]" % [next_level_name, upgrade_pct])
	
	if result.secular_value != 0.0:
		lines.append("[color=#daa520]世俗影响: %.0f[/color]" % result.secular_value)
	if result.literary_value != 0.0:
		lines.append("[color=#87ceeb]文学影响: %.0f[/color]" % result.literary_value)

	$Panel/InputImagPanel/RichTextLabel.text = "\n".join(lines)


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
