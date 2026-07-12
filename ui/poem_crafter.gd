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

## V9.2: 缓存创作代价 operators（切换 mode 时复用，代价与 mode 无关）
var _cached_cost_operators: Array = []

## ──────────────────────────────────────────────
## 文学化评价常量字典
## ──────────────────────────────────────────────

## 意象丰瘠评价 — 按 base_level (1=平庸, 2=佳作, 3=绝唱)
const LITERARY_IMAGERY_TEXTS := {
	1: ["意象贫瘠，恐成陈词滥调", "意象单薄，难成气候", "寥寥数象，勉强成篇"],
	2: ["意象尚可，颇有章法", "意象初具，犹待点睛", "意象得体，渐入佳境"],
	3: ["意象丰沛，气韵生动", "意象纵横，吞吐大荒", "万象在旁，呼之欲出"],
}

## 灵感手感评价 — 按 upgrade_probability 档位: 0=低(<0.33), 1=中(0.33~0.66), 2=高(≥0.66)
const LITERARY_INSPIRATION_TEXTS := {
	0: ["文思枯涩，全凭基本功", "手感生涩，勉力为之", "思绪凝滞，步步为营"],
	1: ["文思渐涌，偶得佳句", "似有灵光，若即若离", "心手渐畅，暗藏机锋"],
	2: ["灵感涌动，如有神助", "才思泉涌，下笔如飞", "灵光乍现，妙手偶得"],
}


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
		Logging.info('PoemCrafter(V9.1): mode → deng_gao（仅刷新第三行，不重算）')
		_refresh_mode_display_only()


func _on_toggle_gan_ye(pressed: bool) -> void:
	if pressed:
		current_mode = "gan_ye"
		Logging.info('PoemCrafter(V9.1): mode → gan_ye（仅刷新第三行，不重算）')
		_refresh_mode_display_only()


## 仅刷新 RichTextLabel 的第三行（精力方向），前两行复用缓存的文本，不重算/不重随机
## V9.2: 代价行也复用缓存，代价与 mode 无关
func _refresh_mode_display_only() -> void:
	if _cached_result == null:
		Logging.info('PoemCrafter(V9.2): _refresh_mode_display_only — 无缓存，跳过')
		return

	# 行1/行2 复用 _preview_current 时缓存的文本，行3 按 current_mode 更新
	var lines: Array[String] = []
	lines.append("[color=#daa520]%s[/color]" % _cached_line1_text)
	lines.append("[color=#87ceeb]%s[/color]" % _cached_line2_text)

	if current_mode == "gan_ye":
		lines.append("[color=#ddd]此诗的精力将倾注于世俗功名之上[/color]")
	else:
		lines.append("[color=#ddd]此诗的精力将倾注于千古文章之上[/color]")

	# V9.2: 代价预览（从缓存 operators 重建，代价与 mode 无关）
	lines.append_array(_build_cost_preview_lines())

	$Panel/InputImagPanel/RichTextLabel.text = "\n\n".join(lines)
	Logging.info('PoemCrafter(V9.2): _refresh_mode_display_only — 已更新, mode=%s, line1=%s' % [current_mode, _cached_line1_text])


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
		$Panel/InputImagPanel/RichTextLabel.text = "已有诗作，先将其送出或题壁后再来。"
		return

	# ── 2. 缓存必须存在（预览阶段已锁定结果） ──
	if _cached_result == null:
		Logging.err('PoemCrafter(V9.1): 缓存缺失 — 预览未完成或已过期，阻断创作')
		$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]出了些问题，稍后再试吧。[/color]"
		return

	var final_level: int = _cached_final_level
	var upgrade_succeeded: bool = _cached_upgrade_succeeded
	Logging.info('PoemCrafter(V9.1): 从缓存读取 — final_level=%d (%s), upgrade=%s' % [final_level, PoemCraftingCalculator.get_level_display_name(final_level), upgrade_succeeded])

	# ── 3. 创建 Poem 对象（V10: 不再绑定 secular/literary value，价值由 PoemRewardOperator 消费时决定） ──
	var level_display_name := PoemCraftingCalculator.get_level_display_name(final_level)
	var poem = Poem.new("POEM", level_display_name)
	poem.uuid = "crafted_poem_l%d_%d" % [final_level, Time.get_unix_time_from_system()]
	poem.name = "《%s》" % level_display_name
	poem.level = final_level
	poem.specific_topic = level_display_name
	Logging.info('PoemCrafter(V10): Poem created — uuid=%s, name=%s, level=%d' % [poem.uuid, poem.name, poem.level])

	PlayerState.created_poems.append(poem)
	Logging.info('PoemCrafter(V10): Poem added to created_poems')

	# 🆕 V10 fix: 注册 Poem 到 PlayerState.traits + Database.traits
	# 使左侧 trait 面板可显示，且 PoemRewardOperator.is_viable() 可查询
	PlayerState.add_trait(poem.uuid)
	Database.traits[poem.uuid] = poem
	Logging.info('PoemCrafter(V10): Poem registered to traits system — uuid=%s' % poem.uuid)

	# ── 4. 先执行创作代价（天数 + 健康消耗）──
	if not _cached_cost_operators.is_empty():
		Logging.info('PoemCrafter(V10): 执行创作代价 — %d 个 operators' % _cached_cost_operators.size())
		_apply_operators(_cached_cost_operators)
	else:
		Logging.warn('PoemCrafter(V10): _cached_cost_operators 为空，跳过代价执行')
	
	# ── 5. V10: 收益算子已删除 — 诗词价值不再创作时立即获得，改由 PoemRewardOperator 消费时产出

	# ── 6. 消耗所有参与计算的 Imaginary ──
	_consume_all_imaginaries()

	# ── 7. 从对应等级的 EventBase 抽取事件 ──
	var event_base_uuid := PoemCraftingCalculator.get_event_base_for_level(final_level)
	var ctx := {
		"poem_level": final_level,
		"poem_level_name": level_display_name,
	}
	Logging.info('PoemCrafter(V10): 从 EventBase 抽事件 — base=%s, ctx=%s' % [event_base_uuid, str(ctx)])

	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("draw_from_event_base"):
		var selected_uuid = event_manager.draw_from_event_base(event_base_uuid, ctx)
		if selected_uuid.is_empty():
			Logging.err('PoemCrafter(V9.1): EventBase 抽取失败，降级使用 push_event "poem_reveal"')
			EventBus.push_event.emit("poem_reveal", ctx)
		else:
			Logging.info('PoemCrafter(V9.1): EventBase 抽取成功 — selected=%s' % selected_uuid)
	else:
		Logging.err('PoemCrafter(V9.1): EventManager 或 draw_from_event_base 不存在，降级使用 push_event "poem_reveal"')
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
	_cached_cost_operators.clear()
	Logging.info('PoemCrafter(V9.2): 缓存已清除（含 cost operators）')


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
	var result := PoemCraftingCalculator.calculate_poem_grade(all_imaginaries, current_mode, max_manageable)

	# ── 2. insufficient ──
	if not result.passed:
		if result.fail_reason == "insufficient":
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]意象不足，至少需要%d个意象方能成诗。[/color]" % max_manageable
			Logging.info('PoemCrafter(V9.1): _preview_current — insufficient, 清除缓存')
		else:
			$Panel/InputImagPanel/RichTextLabel.text = "[color=#aaa]出了些问题…[/color]"
			Logging.err('PoemCrafter(V9.1): _preview_current — 未知错误 fail_reason=%s' % result.fail_reason)
		_cached_result = null
		_cached_final_level = 1
		_cached_upgrade_succeeded = false
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
			Logging.info('PoemCrafter(V9.1): 预览锁定 — 升级成功！roll=%.3f < prob=%.3f → final_level=%d (%s)' % [roll, result.upgrade_probability, _cached_final_level, PoemCraftingCalculator.get_level_display_name(_cached_final_level)])
		else:
			Logging.info('PoemCrafter(V9.1): 预览锁定 — 升级失败 roll=%.3f >= prob=%.3f → final_level=%d (%s)' % [roll, result.upgrade_probability, _cached_final_level, PoemCraftingCalculator.get_level_display_name(_cached_final_level)])
	else:
		Logging.info('PoemCrafter(V9.1): 预览锁定 — 无需升级 base_level=%d (%s), prob=%.3f' % [_cached_final_level, PoemCraftingCalculator.get_level_display_name(_cached_final_level), result.upgrade_probability])

	# ── 4. 构建三行文学评价（缓存选中的文本，切换 mode 时复用） ──
	var lines: Array[String] = []

	# 行 1: 意象丰瘠（#daa520 暗金）— 基于 base_level
	_cached_line1_text = _pick_random_from_pool(LITERARY_IMAGERY_TEXTS.get(result.base_level, ["意象平平"]))
	lines.append("[color=#daa520]%s[/color]" % _cached_line1_text)

	# 行 2: 灵感手感（#87ceeb 天蓝）— 基于 upgrade_probability 三档 / 绝唱特殊文本
	if result.base_level >= 3:
		# 绝唱：固定特殊文本
		_cached_line2_text = "已达化境，随心所欲"
	else:
		var prob: float = result.upgrade_probability
		var tier: int = 0
		if prob >= 0.66:
			tier = 2
		elif prob >= 0.33:
			tier = 1
		else:
			tier = 0
		_cached_line2_text = _pick_random_from_pool(LITERARY_INSPIRATION_TEXTS.get(tier, ["文思平平"]))
		if _cached_upgrade_succeeded:
			_cached_line2_text += "——竟有神来之笔！"
	lines.append("[color=#87ceeb]%s[/color]" % _cached_line2_text)

	# 行 3: 精力方向（white）— 基于 current_mode
	if current_mode == "gan_ye":
		lines.append("[color=#ddd]此诗的精力将倾注于世俗功名之上[/color]")
	else:
		lines.append("[color=#ddd]此诗的精力将倾注于千古文章之上[/color]")

	# ── V9.2: 创作代价预览 ──
	_cached_cost_operators = PoemCraftingCalculator.calculate_crafting_cost(result.score)
	lines.append_array(_build_cost_preview_lines())

	$Panel/InputImagPanel/RichTextLabel.text = "\n\n".join(lines)
	Logging.info('PoemCrafter(V9.2): _preview_current — 渲染完成, final_level=%d, upgrade=%s, line1=%s, cost_ops=%d' % [_cached_final_level, _cached_upgrade_succeeded, _cached_line1_text, _cached_cost_operators.size()])


## 从常量池中随机选一条文本（使用 randi 保证预览评价的微妙变化）
func _pick_random_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return "意象平平"
	return pool[randi() % pool.size()]


## V9.2: 从缓存 cost operators 构建代价预览行（委托给 ActionHintBuilder）
func _build_cost_preview_lines() -> Array[String]:
	var lines: Array[String] = []
	if _cached_cost_operators.is_empty():
		Logging.info("PoemCrafter(V9.2): _build_cost_preview_lines — cost operators 为空，跳过")
		return lines
	
	var previews: Array[String] = ActionHintBuilder.build_operator_preview(_cached_cost_operators)
	if previews.is_empty():
		Logging.info("PoemCrafter(V9.2): _build_cost_preview_lines — ActionHintBuilder 返回空预览")
		return lines
	
	# 分隔线 + 代价行
	lines.append("[color=#cc6666][font_size=13]━━━ 创作代价 ━━━[/font_size][/color]")
	for p in previews:
		lines.append("[color=#cc6666]%s[/color]" % p)
	Logging.info("PoemCrafter(V9.2): _build_cost_preview_lines — %d 行" % previews.size())
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
