extends PanelContainer

## 诗词创作面板 — V13: 意象类型匹配 PoemType + 预览类型效果 + 发布执行 BuffOperator
##
## V13 变更:
##   - 新增意象类型匹配：imaginary_type 计数 → Database.poem_types → PoemType
##   - 预览中展示匹配到的 PoemType 名称 + 组成 + 发布效果
##   - CheckButton「发布」直接执行 PoemType.publication_effects（BuffOperator.operate）
##   - PoemEffectCalculator 重构为纯格式化器（参数从 Poem 改为 PoemType）
##
## V11 保留:
##   - 删除 MODE_TO_INTENT + poem.intent 赋值
##   - 删除随机截断/溢出 Slot 逻辑（FIFO 已保证不溢出）
##   - poem.lore = true（命中配方时标记为有典故）
##   - 保留：纯函数评分制 + 三级事件库 + 全量消耗意象 + 创作代价

const _PoemEffectCalculator = preload("res://core/poem_effect_calculator.gd")

## 当前选中的 toggle mode: "deng_gao" | "gan_ye"
var current_mode: String = "gan_ye"

## Slot 容器路径
const SLOTS_PARENT_PATH := "InputImagPanel/H"

## 浮动灵感容器（复用 tscn 中已有的 Control 节点）
const FLOATING_CONTAINER_PATH := "Control"
var _floating_container: Control = null

## PoemSlot packed scene
const POEM_SLOT_SCENE := preload("res://ui/poem_slot.tscn")

## ──────────────────────────────────────────────
## V9.1: 预览锁定缓存（路线 B：预览即锁定，创作仅确认）
## ──────────────────────────────────────────────

## 预览时锁定的计算结果 — 切换 mode 不重置，仅意象变更时重建
var _cached_result: PoemCraftingCalculator.PoemCraftingResult = null
var _cached_final_level: int = 1
var _cached_upgrade_succeeded: bool = false

## 缓存预览时选中渲染的文本，保证切换 mode 时前两行不变
var _cached_line1_text: String = ""
var _cached_line2_text: String = ""
var _cached_recipe_line: String = ""  ## V12: 配方匹配行文本（空 = 无匹配）
var _cached_poem_type: PoemType = null  ## V13: 匹配到的 PoemType（null = 无匹配）

## V9.2: 缓存创作代价 operators（切换 mode 时复用，代价与 mode 无关）
var _cached_cost_operators: Array = []

## 🆕 mode 即时奖励 operator（切换 mode 时重建，奖励与 mode 相关）
var _cached_mode_reward_operator: PropertyOperator = null

## 🆕 创作诗词所需灵感（兴）消耗
const POEM_CRAFT_INSPIRATION_COST := 20

## ──────────────────────────────────────────────
## 文学化评价常量字典
## ──────────────────────────────────────────────

## 意象丰瘠评价 — 按 base_level (1=平庸, 2=佳作, 3=绝唱)
var LITERARY_IMAGERY_TEXTS := {
	1: [tr("CODE_POEM_CRAFTER_54EAEBD3D3"), tr("CODE_POEM_CRAFTER_728EB1E5A1"), tr("CODE_POEM_CRAFTER_C260C3CC52")],
	2: [tr("CODE_POEM_CRAFTER_BED5C7074B"), tr("CODE_POEM_CRAFTER_DEE7793FFC"), tr("CODE_POEM_CRAFTER_A34283ABC1")],
	3: [tr("CODE_POEM_CRAFTER_161BC32B63"), tr("CODE_POEM_CRAFTER_AB290C38E3"), tr("CODE_POEM_CRAFTER_08CAA7B0F4")],
}

## 灵感手感评价 — 按 upgrade_probability 档位: 0=低(<0.33), 1=中(0.33~0.66), 2=高(≥0.66)
var LITERARY_INSPIRATION_TEXTS := {
	0: [tr("CODE_POEM_CRAFTER_1DBE0EA442"), tr("CODE_POEM_CRAFTER_101706478E"), tr("CODE_POEM_CRAFTER_8F3C2318AC")],
	1: [tr("CODE_POEM_CRAFTER_158B31FA2D"), tr("CODE_POEM_CRAFTER_493B39E86C"), tr("CODE_POEM_CRAFTER_B95E344FCD")],
	2: [tr("CODE_POEM_CRAFTER_8DD341F160"), tr("CODE_POEM_CRAFTER_5971DCC005"), tr("CODE_POEM_CRAFTER_6CCA05DC6F")],
}


func _ready() -> void:
	Logging.info('PoemCrafter: initializing poem crafter V8')

	EventBus.imaginary_changed.connect(on_imaginary_changed)

	# "开始创作"按钮
	var craft_btn := $InputImagPanel/CraftBtn
	if craft_btn:
		craft_btn.pressed.connect(_on_button_pressed)
		Logging.info('PoemCrafter: CraftBtn.pressed 连接成功')

	# "撕毁卷轴"按钮
	var tear_btn := $Button
	if tear_btn:
		tear_btn.pressed.connect(_on_tear_scroll_pressed)

	# Toggle 按钮：监听 button_group 变更
	_connect_toggle_signals()

	# 缓存浮动灵感容器
	_floating_container = get_node_or_null(FLOATING_CONTAINER_PATH)
	if _floating_container:
		Logging.info('PoemCrafter: cached floating container at %s' % FLOATING_CONTAINER_PATH)
	else:
		Logging.warn('PoemCrafter: floating container %s 不存在' % FLOATING_CONTAINER_PATH)

	call_deferred("_rebuild_slots")


# ──────────────────────────────────────────────
# Toggle 模式管理
# ──────────────────────────────────────────────

func _connect_toggle_signals() -> void:
	var btn_deng_gao := $InputImagPanel/VBoxContainer2/Button2
	var btn_gan_ye := $InputImagPanel/VBoxContainer2/Button

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
		Logging.info('PoemCrafter(V9.1): mode → deng_gao（仅刷新第三行，不重算）')
		_refresh_mode_display_only()


func _on_toggle_gan_ye(pressed: bool) -> void:
	if pressed:
		current_mode = "gan_ye"
		Logging.info('PoemCrafter(V9.1): mode → gan_ye（仅刷新第三行，不重算）')
		_refresh_mode_display_only()


## 仅刷新 RichTextLabel 的第三行（精力方向），前两行复用缓存的文本，不重算/不重随机
## V9.2: 代价行也复用缓存，代价与 mode 无关
## V10: 奖励行按 current_mode 重建
func _refresh_mode_display_only() -> void:
	if _cached_result == null:
		Logging.info('PoemCrafter(V9.2): _refresh_mode_display_only — 无缓存，跳过')
		return

	# 🔄 V10: 切换 mode 时重建奖励 operator
	_cached_mode_reward_operator = _build_mode_reward_operator()
	Logging.info('PoemCrafter(V10): _refresh_mode_display_only — 重建奖励 operator, mode=%s' % current_mode)

	# V12: 配方行 + 行1/行2 复用 _preview_current 时缓存的文本，行3 按 current_mode 更新
	var lines: Array[String] = []
	if not _cached_recipe_line.is_empty():
		lines.append(_cached_recipe_line)
	lines.append("[color=#daa520]%s[/color]" % _cached_line1_text)
	lines.append("[color=#87ceeb]%s[/color]" % _cached_line2_text)

	if current_mode == "gan_ye":
		lines.append(tr("CODE_POEM_CRAFTER_FD387E2C9F"))
	else:
		lines.append(tr("CODE_POEM_CRAFTER_C7E02CBBD0"))

	# V13: 类型信息行 — 从缓存 PoemType 重建（切换 mode 时复用）
	if _cached_poem_type:
		lines.append_array(_build_poem_type_preview_lines())
		Logging.info('PoemCrafter(V13): _refresh_mode_display_only — 类型信息行已追加, type=%s' % _cached_poem_type.name)

	# V9.2: 代价预览（从缓存 operators 重建，代价与 mode 无关）
	lines.append_array(_build_cost_preview_lines())

	# 🆕 V10: 奖励预览（按 current_mode 重建，绿色）
	lines.append_array(_build_reward_preview_lines())

	$InputImagPanel/RichTextLabel.text = "\n".join(lines)
	Logging.info('PoemCrafter(V10): _refresh_mode_display_only — 已更新, mode=%s, line1=%s' % [current_mode, _cached_line1_text])


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
		label.text = tr("CODE_POEM_CRAFTER_B6C4708BC5")
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		h_container.add_child(label)
		return

	# V11: FIFO 已保证总数 ≤ max_imaginary_managable，直接全部展示
	Logging.info('PoemCrafter(V11): 展示全部 %d 个 Imaginary（上限=%d）' % [all_imaginaries.size(), PlayerState.max_imaginary_managable])

	# 创建 PoemSlot（所有意象直接展示）
	for imag in all_imaginaries:
		var slot := _create_slot(imag.name, false)
		slot.item_occupying = imag
		h_container.add_child(slot)

	# 自动预览
	_preview_current()

	# 浮动灵感标签
	_rebuild_floating_labels()


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
# 诗词创作 V9.1 — 路线 B：预览锁定，创作仅确认执行
# ──────────────────────────────────────────────

func _on_button_pressed() -> void:
	Logging.info('PoemCrafter(V9.1): _on_button_pressed — 用户确认创作')

	# ── 1. 已有诗作上限检查 ──
	if _has_unused_poem():
		Logging.warn('PoemCrafter(V9.1): 已有未使用的诗词，拒绝创作')
		$InputImagPanel/RichTextLabel.text = tr("CODE_POEM_CRAFTER_357762EA7B")
		return

	# 🆕 灵感（兴）检查：创作诗词需要至少 POEM_CRAFT_INSPIRATION_COST 兴
	var current_inspiration: int = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
	Logging.info('PoemCrafter(V9.1): 灵感检查 — 当前兴=%d, 需要=%d' % [current_inspiration, POEM_CRAFT_INSPIRATION_COST])
	if current_inspiration < POEM_CRAFT_INSPIRATION_COST:
		Logging.warn('PoemCrafter(V9.1): 灵感不足，拒绝创作 — 当前%d < 需要%d' % [current_inspiration, POEM_CRAFT_INSPIRATION_COST])
		$InputImagPanel/RichTextLabel.text = tr("CODE_POEM_CRAFTER_D70FF08DAF") % POEM_CRAFT_INSPIRATION_COST
		return

	# ── 2. 缓存必须存在（预览阶段已锁定结果） ──
	if _cached_result == null:
		Logging.err('PoemCrafter(V9.1): 缓存缺失 — 预览未完成或已过期，阻断创作')
		$InputImagPanel/RichTextLabel.text = tr("CODE_POEM_CRAFTER_3E435BB535")
		return

	var final_level: int = _cached_final_level
	var upgrade_succeeded: bool = _cached_upgrade_succeeded
	Logging.info('PoemCrafter(V11): 从缓存读取 — final_level=%d (%s), upgrade=%s' % [final_level, PoemCraftingCalculator.new().get_level_display_name(final_level), upgrade_succeeded])

	# ── 3. 创建 Poem 对象（V11: 删除 intent，价值由 PoemRewardOperator 消费时决定） ──
	# V12: 优先使用配方匹配数据，匹配失败则回退通用名
	var level_display_name := PoemCraftingCalculator.new().get_level_display_name(final_level)
	var matched: Poem = _cached_result.matched_recipe
	var poem: Poem
	var poem_name: String
	var poem_specific: String
	
	if matched:
		# 命中配方 → 使用配方的真实诗名 / specific_topic / required_fragments
		poem = Poem.new("POEM", matched.specific_topic)
		poem.uuid = "crafted_poem_l%d_%d" % [final_level, Time.get_unix_time_from_system()]
		poem.name = "《%s》" % tr(matched.name)
		poem.level = final_level
		poem.specific_topic = matched.specific_topic
		poem.required_fragments = matched.required_fragments.duplicate()
		poem.lore = true  # V11: 命中配方 → 标记为有典故
		Logging.info('PoemCrafter(V11): Poem from recipe — uuid=%s, name=%s, level=%d, topic=%s, lore=true, recipe_uuid=%s' % [poem.uuid, poem.name, poem.level, matched.specific_topic, matched.uuid])
	else:
		# 无匹配配方 → 回退通用名
		poem = Poem.new("POEM", level_display_name)
		poem.uuid = "crafted_poem_l%d_%d" % [final_level, Time.get_unix_time_from_system()]
		poem.name = "《%s》" % level_display_name
		poem.level = final_level
		poem.specific_topic = level_display_name
		Logging.info('PoemCrafter(V11): Poem generic fallback — uuid=%s, name=%s, level=%d' % [poem.uuid, poem.name, poem.level])

	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter(V10): Poem added to created_poems')
	EventBus.poems_created.emit([poem])
	Logging.info('PoemCrafter(V10): poems_created signal emitted — uuid=%s' % poem.uuid)

	# 🆕 V10 fix: 注册 Poem 到 PlayerState.traits + Database.traits
	# 使左侧 trait 面板可显示，且 PoemRewardOperator.is_viable() 可查询
	PlayerState.add_trait(poem.uuid)
	Database.traits[poem.uuid] = poem
	Logging.info('PoemCrafter(V10): Poem registered to traits system — uuid=%s' % poem.uuid)

	# 🆕 消耗灵感（兴）：创作固定消耗 POEM_CRAFT_INSPIRATION_COST 兴
	var insp_cost := -POEM_CRAFT_INSPIRATION_COST
	PlayerState.append_stat(ENUMS.PROPS.INSPIRATION, insp_cost)
	Logging.info('PoemCrafter(V10): 消耗灵感(兴) — PoEM_CRAFT_INSPIRATION_COST=%d, 当前兴=%d' % [POEM_CRAFT_INSPIRATION_COST, PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)])

	# ── 4. 先执行创作代价（天数 + 健康消耗）──
	if not _cached_cost_operators.is_empty():
		Logging.info('PoemCrafter(V10): 执行创作代价 — %d 个 operators' % _cached_cost_operators.size())
		_apply_operators(_cached_cost_operators)
	else:
		Logging.warn('PoemCrafter(V10): _cached_cost_operators 为空，跳过代价执行')
	
	# ── 5. V10: 即时创作激励 — mode 决定即时奖励（登高→声望 / 干谒→金钱）──
	if _cached_mode_reward_operator:
		Logging.info('PoemCrafter(V10): 执行创作激励 — mode=%s, prop=%s, val=%d' % [current_mode, _cached_mode_reward_operator.property, _cached_mode_reward_operator.value])
		_cached_mode_reward_operator.operate()
	else:
		Logging.warn('PoemCrafter(V10): _cached_mode_reward_operator 为空，跳过创作激励')

	# ── 6. V11: 统计消耗前的意象分类（供 TagManager stance 计算）──
	var type_counts: Dictionary = {}
	for uuid in Database.imaginaries_detail:
		var imag = Database.imaginaries_detail[uuid]
		if imag is Imaginary and not imag.imaginary_type.is_empty():
			type_counts[imag.imaginary_type] = type_counts.get(imag.imaginary_type, 0) + 1
	poem.used_imaginary_types = type_counts
	Logging.info('PoemCrafter(V11): used_imaginary_types=%s' % str(type_counts))

	# ── 7. 消耗所有参与计算的 Imaginary ──
	_consume_all_imaginaries()

	# ── 8. V14: 发布按钮 — 执行 PoemType.publication_effects（Array[BaseOperator]）+ 格式化 effect_desc ──
	var publish_checkbtn := $InputImagPanel/CheckButton as CheckButton
	var effect_desc: String = ""
	if publish_checkbtn and publish_checkbtn.button_pressed:
		# 8a. 遍历 publication_effects → BaseOperator.operate()
		if _cached_poem_type and not _cached_poem_type.publication_effects.is_empty():
			Logging.info('PoemCrafter(V14): 发布按钮已勾选 — 执行 %d 个 BaseOperator' % _cached_poem_type.publication_effects.size())
			for op in _cached_poem_type.publication_effects:
				if not op:
					Logging.warn('PoemCrafter(V14): publication_effects 中包含 null 元素，跳过')
					continue
				if op is BuffOperator:
					op.source_uuid = poem.uuid
					op.operate()
					Logging.info('PoemCrafter(V14): BuffOperator 已执行 — source=%s, type=%s, named_key=%s' % [op.source_uuid, op.modifier_type, op.named_amount_key])
				elif op is PropertyOperator:
					op.operate()
					Logging.info('PoemCrafter(V14): PropertyOperator 已执行 — property=%s, value=%+d' % [op.property, op.value])
				elif op.has_method("operate"):
					op.operate()
					Logging.info('PoemCrafter(V14): BaseOperator 已执行 — class=%s' % op.get_class())
				else:
					Logging.warn('PoemCrafter(V14): publication_effects 中包含无 operate() 的元素 (class=%s)，跳过' % op.get_class())
		else:
			Logging.info('PoemCrafter(V14): 发布按钮已勾选但无有效的 publication_effects')

		# 8b. 用 PoemEffectCalculator 格式化效果描述
		var effect_result := _PoemEffectCalculator.calculate(_cached_poem_type)
		effect_desc = effect_result.effect_desc
		Logging.info('PoemCrafter(V14): 发布效果格式化 — effect_desc=%s' % effect_desc)
	else:
		Logging.info('PoemCrafter(V14): 发布按钮未勾选，跳过发布')

	# ── 8. 从对应等级的 EventBase 抽取事件 ──
	var event_base_uuid := PoemCraftingCalculator.get_event_base_for_level(final_level)
	var ctx := {
		"poem_level": final_level,
		"poem_level_name": level_display_name,
		"publish_effect": effect_desc,  # V11: 发布效果描述（空="未发布"）
	}
	Logging.info('PoemCrafter(V11): 从 EventBase 抽事件 — base=%s, ctx=%s' % [event_base_uuid, str(ctx)])

	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("draw_from_event_base"):
		var selected_uuid = event_manager.draw_from_event_base(event_base_uuid, ctx)
		if selected_uuid.is_empty():
			Logging.err('PoemCrafter(V11): EventBase 抽取失败，降级使用 push_event "poem_reveal"')
			EventBus.push_event.emit("poem_reveal", ctx)
		else:
			Logging.info('PoemCrafter(V11): EventBase 抽取成功 — selected=%s' % selected_uuid)
	else:
		Logging.err('PoemCrafter(V11): EventManager 或 draw_from_event_base 不存在，降级使用 push_event "poem_reveal"')
		EventBus.push_event.emit("poem_reveal", ctx)

	# ── 9. 清除缓存并重建 Slot ──
	_clear_cached_result()
	_rebuild_slots()

	# 🆕 创作完成 → 自动关闭 PoemCreationPage（触发卷轴退出动画 + 面板滑回 + tape 恢复）
	EventBus.poem_cancel.emit()


## 清除预览缓存（创作完成后 / insufficient 后调用）
func _clear_cached_result() -> void:
	_cached_result = null
	_cached_final_level = 1
	_cached_upgrade_succeeded = false
	_cached_line1_text = ""
	_cached_line2_text = ""
	_cached_recipe_line = ""
	_cached_poem_type = null
	_cached_cost_operators.clear()
	_cached_mode_reward_operator = null
	Logging.info('PoemCrafter(V13): 缓存已清除（含 cost operators + reward + recipe + poem_type）')


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
	# V10: 优先检查 created_poems（直接遍历 Poem 对象，O(n)）
	for entry in PlayerState.created_poems:
		if entry is Poem and entry.topic == "POEM":
			Logging.info('PoemCrafter: 检测到已有诗词 in created_poems: %s' % entry.uuid)
			return true
	# V10: 再检查 PlayerState.traits 中的 Poem（通过 Database.traits 解析）
	# uuid 前缀已从 poem_recipe_ 改为 crafted_poem_，使用通用 is Poem 检查更健壮
	for trait_uuid in PlayerState.traits:
		var t = Database.get_trait(trait_uuid)
		if t != null and t is Poem and t.topic == "POEM":
			Logging.info('PoemCrafter: 检测到已有诗词 trait: %s (%s)' % [t.name, t.uuid])
			return true
	Logging.info('PoemCrafter: 未检测到任何未使用诗词')
	return false


func _apply_operators(ops: Array) -> void:
	for op in ops:
		if op and op.has_method("execute"):
			op.execute()
		elif op and op.has_method("operate"):
			op.operate()


# ──────────────────────────────────────────────
# V9.1 文学化预览（路线 B：预览即锁定，创作仅确认）
# ──────────────────────────────────────────────

func _preview_current() -> void:
	var all_imaginaries := _get_all_valid_imaginaries()
	var max_manageable: int = PlayerState.max_imaginary_managable

	Logging.info('PoemCrafter(V9.1): _preview_current — 意象数=%d, mode=%s' % [all_imaginaries.size(), current_mode])

	# ── 1. 纯函数计算 ──
	var result := PoemCraftingCalculator.new().calculate_poem_grade(all_imaginaries, current_mode, max_manageable)

	# ── 2. insufficient ──
	if not result.passed:
		if result.fail_reason == "insufficient":
			$InputImagPanel/RichTextLabel.text = tr("CODE_POEM_CRAFTER_46DC19151B") % max_manageable
			Logging.info('PoemCrafter(V9.1): _preview_current — insufficient, 清除缓存')
		else:
			$InputImagPanel/RichTextLabel.text = tr("CODE_POEM_CRAFTER_9050E24622")
			Logging.err('PoemCrafter(V9.1): _preview_current — 未知错误 fail_reason=%s' % result.fail_reason)
		_cached_result = null
		_cached_final_level = 1
		_cached_upgrade_succeeded = false
		_cached_recipe_line = ""
		return

	# ── 3. 掷骰子锁定结果（路线 B：预览即锁定） ──
	_cached_result = result
	_cached_final_level = result.base_level
	_cached_upgrade_succeeded = false

	if _cached_final_level < 3 and result.upgrade_probability > 0.0:
		var roll: float = randf()
		if roll < result.upgrade_probability:
			_cached_final_level += 1
			_cached_upgrade_succeeded = true
			Logging.info('PoemCrafter(V9.1): 预览锁定 — 升级成功！roll=%.3f < prob=%.3f → final_level=%d (%s)' % [roll, result.upgrade_probability, _cached_final_level, PoemCraftingCalculator.new().get_level_display_name(_cached_final_level)])
		else:
			Logging.info('PoemCrafter(V9.1): 预览锁定 — 升级失败 roll=%.3f >= prob=%.3f → final_level=%d (%s)' % [roll, result.upgrade_probability, _cached_final_level, PoemCraftingCalculator.new().get_level_display_name(_cached_final_level)])
	else:
		Logging.info('PoemCrafter(V9.1): 预览锁定 — 无需升级 base_level=%d (%s), prob=%.3f' % [_cached_final_level, PoemCraftingCalculator.new().get_level_display_name(_cached_final_level), result.upgrade_probability])

	# ── 4. 构建预览（缓存选中的文本，切换 mode 时复用） ──
	var lines: Array[String] = []
	
	# V12: 配方匹配行（#ffd700 金色）— 命中配方时显示诗名
	var recipe: Poem = result.matched_recipe
	if recipe:
		_cached_recipe_line = "[color=#ffd700]「%s」[/color]" % tr(recipe.name)
		lines.append(_cached_recipe_line)
		Logging.info('PoemCrafter(V12): _preview_current — 配方预览: %s' % recipe.name)
	else:
		_cached_recipe_line = ""

	# 行 1: 意象丰瘠（#daa520 暗金）— 基于 base_level
	_cached_line1_text = _pick_random_from_pool(LITERARY_IMAGERY_TEXTS.get(result.base_level, [tr("CODE_POEM_CRAFTER_7D1B3E04F1")]))
	lines.append("[color=#daa520]%s[/color]" % _cached_line1_text)

	# 行 2: 灵感手感（#87ceeb 天蓝）— 基于 upgrade_probability 三档 / 绝唱特殊文本
	if result.base_level >= 3:
		# 绝唱：固定特殊文本
		_cached_line2_text = tr("CODE_POEM_CRAFTER_DA3A618F49")
	else:
		var prob: float = result.upgrade_probability
		var tier: int = 0
		if prob >= 0.66:
			tier = 2
		elif prob >= 0.33:
			tier = 1
		else:
			tier = 0
		_cached_line2_text = _pick_random_from_pool(LITERARY_INSPIRATION_TEXTS.get(tier, [tr("CODE_POEM_CRAFTER_6510BE12F0")]))
		if _cached_upgrade_succeeded:
			_cached_line2_text += tr("CODE_POEM_CRAFTER_DFCDFD5D28")
	lines.append("[color=#87ceeb]%s[/color]" % _cached_line2_text)

	# 行 3: 精力方向（white）— 基于 current_mode
	if current_mode == "gan_ye":
		lines.append(tr("CODE_POEM_CRAFTER_FD387E2C9F"))
	else:
		lines.append(tr("CODE_POEM_CRAFTER_C7E02CBBD0"))

	# ── V13: 类型信息行 — 匹配到的 PoemType 名称 + 组成 + 发布效果 ──
	_cached_poem_type = result.matched_poem_type
	if _cached_poem_type:
		lines.append_array(_build_poem_type_preview_lines())
		Logging.info('PoemCrafter(V13): _preview_current — 类型信息已缓存, type=%s' % _cached_poem_type.name)
	else:
		Logging.info('PoemCrafter(V13): _preview_current — 无匹配 PoemType，跳过类型信息行')

	# ── V9.2: 创作代价预览 ──
	_cached_cost_operators = PoemCraftingCalculator.calculate_crafting_cost(result.score)
	lines.append_array(_build_cost_preview_lines())

	# 🆕 V10: 创作激励预览（按 current_mode 构建 reward operator，绿色）
	_cached_mode_reward_operator = _build_mode_reward_operator()
	lines.append_array(_build_reward_preview_lines())

	$InputImagPanel/RichTextLabel.text = "\n".join(lines)
	Logging.info('PoemCrafter(V10): _preview_current — 渲染完成, final_level=%d, upgrade=%s, line1=%s, cost_ops=%d, reward=%s' % [_cached_final_level, _cached_upgrade_succeeded, _cached_line1_text, _cached_cost_operators.size(), current_mode])


## 从常量池中随机选一条文本（使用 randi 保证预览评价的微妙变化）
func _pick_random_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return tr("CODE_POEM_CRAFTER_7D1B3E04F1")
	return pool[randi() % pool.size()]


## V9.2: 从缓存 cost operators 构建代价预览行（委托给 ActionHintBuilder）
## 🆕 额外追加灵感（兴）消耗预览
func _build_cost_preview_lines() -> Array[String]:
	var lines: Array[String] = []
	
	# 分隔线
	lines.append(BBCode.color_size(tr("CODE_POEM_CRAFTER_5149591659"), BBCode.COLOR_DANGER, 13))
	
	# 🆕 灵感消耗预览（始终显示）
	var current_inspiration: int = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
	var insp_preview: String = tr("CODE_POEM_CRAFTER_659C9410D1") % POEM_CRAFT_INSPIRATION_COST
	if current_inspiration < POEM_CRAFT_INSPIRATION_COST:
		insp_preview += tr("CODE_POEM_CRAFTER_5DADE3605B")
	insp_preview += tr("CODE_POEM_CRAFTER_7150BC2988") % current_inspiration
	lines.append(BBCode.color(insp_preview, BBCode.COLOR_DANGER))
	
	# 时间/健康代价（来自 _cached_cost_operators）
	if not _cached_cost_operators.is_empty():
		var previews: Array[String] = ActionHintBuilder.new().build_operator_preview(_cached_cost_operators)
		for p in previews:
			lines.append(BBCode.color(p, BBCode.COLOR_DANGER))
	
	Logging.info("PoemCrafter(V9.2): _build_cost_preview_lines — 灵感消耗=%d, cost_ops=%d, 总%d行" % [POEM_CRAFT_INSPIRATION_COST, _cached_cost_operators.size(), lines.size()])
	return lines


## 🆕 V10: 根据 current_mode 构建即时奖励 PropertyOperator（M档）
## 纯函数，无副作用。调用方负责缓存和展示。
func _build_mode_reward_operator() -> PropertyOperator:
	var op := PropertyOperator.new()
	var amounts := NamedDSLParser._load_named_amounts()

	if current_mode == "gan_ye":
		# 干谒权贵 → 金钱 M 档 (m_money_gain = 30)
		op.property = "money"
		op.value = amounts.get("m_money_gain", 30)
		Logging.info('PoemCrafter(V10): _build_mode_reward_operator — gan_ye → money +%d' % op.value)
	else:
		# 登高抒怀 → 文学声望 M 档 (m_prestige_gain = 5)
		op.property = "prestige"
		op.value = amounts.get("m_prestige_gain", 5)
		Logging.info('PoemCrafter(V10): _build_mode_reward_operator — deng_gao → prestige +%d' % op.value)

	return op


## 🆕 V10: 从缓存 mode_reward_operator 构建奖励预览行（绿色 #66cc66）
func _build_reward_preview_lines() -> Array[String]:
	var lines: Array[String] = []

	if _cached_mode_reward_operator == null:
		Logging.warn('PoemCrafter(V10): _build_reward_preview_lines — _cached_mode_reward_operator 为空，跳过')
		return lines

	# 分隔线（绿色）
	lines.append(BBCode.color_size(tr("CODE_POEM_CRAFTER_REWARD_SECTION"), BBCode.COLOR_SUCCESS, 13))

	# 奖励描述（复用 PropertyOperator.describe_preview，绿色）
	var desc: String = _cached_mode_reward_operator.describe_preview()
	if not desc.is_empty():
		lines.append(BBCode.color(desc, BBCode.COLOR_SUCCESS))
		Logging.info('PoemCrafter(V10): _build_reward_preview_lines — mode=%s, desc=%s' % [current_mode, desc])
	else:
		Logging.warn('PoemCrafter(V10): _build_reward_preview_lines — describe_preview 返回空字符串')

	Logging.info('PoemCrafter(V10): _build_reward_preview_lines — 总%d行' % lines.size())
	return lines


## 🆕 V13: 从缓存 _cached_poem_type 构建类型信息预览行
## 展示：分隔线 + 类型名 + 组成（三项用" + "连接）+ 发布效果（BuffOperator.describe_preview）
func _build_poem_type_preview_lines() -> Array[String]:
	var lines: Array[String] = []

	if _cached_poem_type == null:
		Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — _cached_poem_type 为空，跳过')
		return lines

	# 分隔线（金棕）
	lines.append(BBCode.color_size(tr("CODE_POEM_CRAFTER_TYPE_SECTION"), BBCode.COLOR_WARNING, 13))

	# 类型名
	var type_name := tr(_cached_poem_type.name) if not _cached_poem_type.name.is_empty() else _cached_poem_type.uuid
	lines.append(BBCode.color(tr("CODE_POEM_CRAFTER_TYPE_NAME") % type_name, BBCode.COLOR_WARNING))
	Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — type_name=%s' % type_name)

	# 组成：三项用 tr() 翻译后用 " + " 连接（无颜色包裹）
	var comp_parts: Array[String] = []
	for c in _cached_poem_type.composition:
		comp_parts.append(tr(c))
	lines.append(tr("CODE_POEM_CRAFTER_TYPE_COMPOSITION") % " + ".join(comp_parts))
	Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — composition=%s' % str(comp_parts))

	# 发布效果：遍历 publication_effects
	var effect_text := _cached_poem_type.get_effects_text()
	if effect_text.is_empty():
		lines.append(BBCode.color(tr("CODE_POEM_CRAFTER_TYPE_NO_EFFECT"), BBCode.COLOR_MUTED))
		Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — 无发布效果')
	else:
		lines.append(tr("CODE_POEM_CRAFTER_TYPE_EFFECT") % effect_text)
		Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — effect=%s' % effect_text)

	Logging.info('PoemCrafter(V13): _build_poem_type_preview_lines — 总%d行' % lines.size())
	return lines


# ──────────────────────────────────────────────
# 拒写机制
# ──────────────────────────────────────────────

func _on_tear_scroll_pressed() -> void:
	Logging.info('PoemCrafter: 撕毁卷轴 — 拒写')

	var amounts = NamedDSLParser._load_named_amounts()
	var loss = amounts.get("s_fame_cost", -10)
	PlayerState.append_stat("prestige", loss)
	Logging.info('PoemCrafter: 扣除 prestige %d' % loss)
	EventBus.exit_poem_page.emit()
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
	# 先清理浮动灵感标签
	_cleanup_floating_labels()

	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "position:y", position.y + 10, 0.3)
	await tw.finished
	hide()
	EventBus.exit_poem_page.emit()
	Logging.info("PoemCrafter: hide_with_animation 完成")


# ──────────────────────────────────────────────
# 浮动灵感标签管理
# ──────────────────────────────────────────────

## 重建浮动灵感标签（与 HBox Slots 并行，纯氛围层）
func _rebuild_floating_labels() -> void:
	_cleanup_floating_labels()

	if not _floating_container:
		Logging.warn('PoemCrafter: _floating_container 不存在，跳过浮动标签重建')
		return

	var all_imaginaries := _get_all_valid_imaginaries()
	if all_imaginaries.is_empty():
		Logging.info('PoemCrafter: 无意象，跳过浮动标签重建')
		return

	for imag in all_imaginaries:
		var label := FloatingImaginaryLabel.new()
		label.setup(imag.name, imag.level)
		_floating_container.add_child(label)

	Logging.info('PoemCrafter: 创建 %d 个浮动灵感标签' % all_imaginaries.size())


## 清理所有浮动灵感标签
func _cleanup_floating_labels() -> void:
	if not _floating_container:
		return

	var count := 0
	for child in _floating_container.get_children():
		if child is FloatingImaginaryLabel:
			child.stop_and_cleanup()
			count += 1
		# 保留"wasd移动" Label（非 FloatingImaginaryLabel 的都不删）
		# 只移除 FloatingImaginaryLabel 实例
	for child in _floating_container.get_children():
		if child is FloatingImaginaryLabel:
			_floating_container.remove_child(child)
			child.queue_free()

	if count > 0:
		Logging.info('PoemCrafter: 清理 %d 个浮动灵感标签' % count)
