class_name TombstoneScreen extends CanvasLayer

const FinalPoemLabelScene: PackedScene = preload("res://ui/final_poem_label.tscn")

# 打字机速度（秒/字）
const TYPE_SPEED: float = 0.04
# SubViewport 诗词并行打字总时长（秒）
const POEM_TWEEN_DURATION: float = 2.0

# ── 原有引用 ──
@onready var portrait_rect: TextureRect = $ColorRect/M/H/M/Portrait
@onready var sub_viewport: SubViewport = $ColorRect/M/H/V/PanelContainer/S/V/SubViewportContainer/SubViewport

# ── 打字机 label 引用 ──
@onready var reason_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/Reason
@onready var judgement_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/Judgement
@onready var time_action_rank_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/TimeActionRank
@onready var specific_resource_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/SpecificResource
@onready var midware_product_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/MidwareProduct
@onready var history_title_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/HistoryTitle
@onready var history_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/History
@onready var but_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/BUT
@onready var poem_assessment_label: Label = $ColorRect/M/H/V/PanelContainer/S/V/PoemAssessment
@onready var exit_button: Button = $ColorRect/M/H/V/Button
@onready var continue_button: Button = $ColorRect/M/H/V/PanelContainer/S/V/ContinueButton

# ── 非打字机节点引用 ──
@onready var title_hbox: HBoxContainer = $ColorRect/M/H/V/PanelContainer/S/V/TitleHbox
@onready var sub_viewport_container: SubViewportContainer = $ColorRect/M/H/V/PanelContainer/S/V/SubViewportContainer

func _ready():
	Logging.info('TombstoneScreen._ready: entering as standalone scene root, reading death_reason/death_tutorial from GameState')

	# 初始状态：隐藏所有打字机 label 和按钮
	_hide_all_typewriter_labels()

	# 标题行、小节标题、过渡语直接显示（不参与打字机）
	title_hbox.visible = true
	history_title_label.visible = true
	but_label.visible = true

	render_entropy_death()
	EventBus.request_return_to_main_menu.connect(_on_return_to_main_menu)
	Logging.info('TombstoneScreen._ready: connected to request_return_to_main_menu signal')


# ════════════════════════════════════════════════════════════════
# 初始状态重置
# ════════════════════════════════════════════════════════════════

func _hide_all_typewriter_labels() -> void:
	reason_label.visible = false
	judgement_label.visible = false
	time_action_rank_label.visible = false
	specific_resource_label.visible = false
	midware_product_label.visible = false
	history_label.visible = false
	poem_assessment_label.visible = false
	sub_viewport_container.visible = false
	exit_button.visible = false
	continue_button.visible = false
	Logging.info('TombstoneScreen._hide_all_typewriter_labels: all typewriter labels hidden')


# ════════════════════════════════════════════════════════════════
# 核心接口：接收死因与评语，填充 label 文本，启动打字机
# ════════════════════════════════════════════════════════════════

func render_entropy_death() -> void:
	Logging.info('TombstoneScreen.render_entropy_death: start')

	_populate_label_texts()
	_populate_poems()

	# 启动打字机序列（fire-and-forget 协程）
	_typewrite_sequence()
	Logging.info('TombstoneScreen.render_entropy_death: typewrite sequence launched')


# ════════════════════════════════════════════════════════════════
# 填充各 label 文本（优先 GameState 数据，fallback 到 tscn 占位文本）
# ════════════════════════════════════════════════════════════════

func _populate_label_texts() -> void:
	# Reason — 死因
	if not GameState.death_reason.is_empty():
		reason_label.text = tr(GameState.death_reason)
		Logging.info('TombstoneScreen._populate_label_texts: reason=%s' % reason_label.text)
	else:
		Logging.info('TombstoneScreen._populate_label_texts: death_reason empty, keeping tscn placeholder')

	# Judgement — 死亡评语
	if not GameState.death_tutorial.is_empty():
		judgement_label.text = tr(GameState.death_tutorial)
		Logging.info('TombstoneScreen._populate_label_texts: judgement=%s' % judgement_label.text)
	else:
		Logging.info('TombstoneScreen._populate_label_texts: death_tutorial empty, keeping tscn placeholder')

	# Drained resource — 记录日志
	if not GameState.drained_resource_type.is_empty():
		Logging.info('TombstoneScreen._populate_label_texts: drained_resource_type=%s' % GameState.drained_resource_type)

	_populate_time_action_rank()
	_populate_specific_resource()
	_populate_midware_product()
	_populate_history()
	_populate_poem_assessment()
	Logging.info('TombstoneScreen._populate_label_texts: done — all 5 data labels populated from PlayerObserver')


# ════════════════════════════════════════════════════════════════
# 诗词填充：从 PlayerState.created_poems 获取，随机铺排到 SubViewport
# ════════════════════════════════════════════════════════════════

func _populate_poems() -> void:
	Logging.info('TombstoneScreen._populate_poems: start')

	# 清空 SubViewport 现有子节点（包括 placeholder label）
	for child in sub_viewport.get_children():
		child.queue_free()
	Logging.info('TombstoneScreen._populate_poems: cleared existing children')

	var poems: Array = PlayerState.created_poems
	if poems.is_empty():
		Logging.info('TombstoneScreen._populate_poems: PlayerState.created_poems is empty, nothing to render')
		return

	Logging.info('TombstoneScreen._populate_poems: got %d poems from PlayerState.created_poems' % poems.size())

	var viewport_size: Vector2 = sub_viewport.size
	Logging.info('TombstoneScreen._populate_poems: viewport size = %s' % str(viewport_size))

	var idx: int = 0
	for poem in poems:
		if not poem is Poem:
			Logging.info('TombstoneScreen._populate_poems: idx=%d is not a Poem (%s), skipping' % [idx, poem.get_class() if poem else "null"])
			idx += 1
			continue

		if poem.name.is_empty():
			Logging.info('TombstoneScreen._populate_poems: idx=%d Poem has empty name, skipping' % idx)
			idx += 1
			continue

		var label: RichTextLabel = FinalPoemLabelScene.instantiate()
		if not label:
			Logging.err('TombstoneScreen._populate_poems: idx=%d failed to instantiate final_poem_label.tscn' % idx)
			idx += 1
			continue

		label.text = poem.name
		Logging.info('TombstoneScreen._populate_poems: idx=%d poem.name=%s' % [idx, poem.name])

		# 随机放置：约束在 viewport 边界内
		var label_w: float = label.size.x if label.size.x > 0 else 240.0
		var label_h: float = label.size.y if label.size.y > 0 else 30.0
		var max_x: float = max(viewport_size.x - label_w, 0.0)
		var max_y: float = max(viewport_size.y - label_h, 0.0)

		label.position = Vector2(randf_range(0.0, max_x), randf_range(0.0, max_y))
		Logging.info('TombstoneScreen._populate_poems: idx=%d position=%s' % [idx, str(label.position)])

		# 随机染色：RGB 随机 + alpha 在 0.70~0.95 之间
		label.self_modulate = Color(randf(), randf(), randf(), randf_range(0.70, 0.95))
		Logging.info('TombstoneScreen._populate_poems: idx=%d self_modulate=%s' % [idx, str(label.self_modulate)])

		sub_viewport.add_child(label)
		Logging.info('TombstoneScreen._populate_poems: idx=%d added to sub_viewport' % idx)
		idx += 1

	Logging.info('TombstoneScreen._populate_poems: done, %d labels added' % sub_viewport.get_child_count())


# ════════════════════════════════════════════════════════════════
# 打字机主序列 — 从上到下逐 label 打字
# ════════════════════════════════════════════════════════════════

func _typewrite_sequence() -> void:
	Logging.info('TombstoneScreen._typewrite_sequence: begin')

	# Step 1: Reason（死因）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 1 — Reason')
	reason_label.visible = true
	await _typewrite_label(reason_label, reason_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: Reason done')

	# Step 2: Judgement（评语）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 2 — Judgement')
	judgement_label.visible = true
	await _typewrite_label(judgement_label, judgement_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: Judgement done')

	# Step 3: TimeActionRank（时间/行动排名）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 3 — TimeActionRank')
	time_action_rank_label.visible = true
	await _typewrite_label(time_action_rank_label, time_action_rank_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: TimeActionRank done')

	# Step 4: SpecificResource（特定资源消耗细节）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 4 — SpecificResource')
	specific_resource_label.visible = true
	await _typewrite_label(specific_resource_label, specific_resource_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: SpecificResource done')

	# Step 5: MidwareProduct（产出统计）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 5 — MidwareProduct')
	midware_product_label.visible = true
	await _typewrite_label(midware_product_label, midware_product_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: MidwareProduct done')

	# Step 6: History（历史事件记录）
	# HistoryTitle 已在 _ready 中 visible=true，不参与打字机
	Logging.info('TombstoneScreen._typewrite_sequence: Step 6 — History')
	history_label.visible = true
	await _typewrite_label(history_label, history_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: History done')

	# BUT 过渡语已在 _ready 中 visible=true，不参与打字机

	# Step 7: SubViewport 诗词 — 所有诗词同时并行打字
	Logging.info('TombstoneScreen._typewrite_sequence: Step 7 — Poems (parallel)')
	sub_viewport_container.visible = true
	await _typewrite_poems_parallel()
	Logging.info('TombstoneScreen._typewrite_sequence: Poems done')

	# Step 8: PoemAssessment（诗词评价）
	Logging.info('TombstoneScreen._typewrite_sequence: Step 8 — PoemAssessment')
	poem_assessment_label.visible = true
	await _typewrite_label(poem_assessment_label, poem_assessment_label.text, TYPE_SPEED)
	Logging.info('TombstoneScreen._typewrite_sequence: PoemAssessment done')

	# Step 9: 检测隐藏结局 → 显示对应按钮
	if _is_hidden_ending():
		continue_button.visible = true
		Logging.info('TombstoneScreen._typewrite_sequence: all done, hidden ending detected → continue button shown')
	else:
		exit_button.visible = true
		Logging.info('TombstoneScreen._typewrite_sequence: all done, exit button shown')


# ════════════════════════════════════════════════════════════════
# 打字机基础设施
# ════════════════════════════════════════════════════════════════

## 对单个 Label 执行逐字打字机。
## 策略：预填充确定高度 → 锁定 custom_minimum_size 防抖 → 清空 → 逐字填充
func _typewrite_label(label: Label, full_text: String, speed: float) -> void:
	if full_text.is_empty():
		Logging.info('TombstoneScreen._typewrite_label: text empty, skipping')
		return

	Logging.info('TombstoneScreen._typewrite_label: start — %d chars, speed=%f' % [full_text.length(), speed])

	# Phase 1: 预填充全文 → 等一帧让 VBoxContainer 完成布局 → 锁定最小高度
	label.text = full_text
	await get_tree().process_frame
	label.custom_minimum_size.y = label.size.y
	Logging.info('TombstoneScreen._typewrite_label: locked height at %.1f' % label.size.y)

	# Phase 2: 清空，逐字打字
	label.text = ""
	for i in range(full_text.length()):
		label.text = full_text.left(i + 1)
		if speed > 0.0:
			await _wait(speed)

	Logging.info('TombstoneScreen._typewrite_label: done')


## SubViewport 内所有 RichTextLabel 同时并行打字。
## 策略：全部设 visible_characters=0 → 创建并行 Tween 同时动画到各自全长
func _typewrite_poems_parallel() -> void:
	var poem_labels: Array[RichTextLabel] = []
	for child in sub_viewport.get_children():
		if child is RichTextLabel:
			poem_labels.append(child)

	if poem_labels.is_empty():
		Logging.info('TombstoneScreen._typewrite_poems_parallel: no RichTextLabel children in SubViewport, skipping')
		return

	Logging.info('TombstoneScreen._typewrite_poems_parallel: %d poem labels to animate' % poem_labels.size())

	# 全部设为 0 visible_characters
	for label in poem_labels:
		label.visible_characters = 0
		Logging.info('TombstoneScreen._typewrite_poems_parallel: label text=%d chars, reset visible_characters=0' % label.text.length())

	# 并行 Tween
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	for label in poem_labels:
		var target_chars: int = label.text.length()
		tween.tween_property(label, "visible_characters", target_chars, POEM_TWEEN_DURATION)
		Logging.info('TombstoneScreen._typewrite_poems_parallel: tween target=%d chars for label' % target_chars)

	await tween.finished
	Logging.info('TombstoneScreen._typewrite_poems_parallel: all poem tweens finished')


## 不受世界暂停影响的异步等待
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.start()
	Logging.info('TombstoneScreen._wait: %.2fs' % seconds)
	await timer.timeout
	timer.queue_free()


# ════════════════════════════════════════════════════════════════
# 按钮 / 信号回调
# ════════════════════════════════════════════════════════════════

func _is_hidden_ending() -> bool:
	var result: bool = GameState.death_reason == "ENDING_HIDDEN_REASON"
	Logging.info('TombstoneScreen._is_hidden_ending: death_reason="%s" → %s' % [GameState.death_reason, result])
	return result


func _on_button_pressed() -> void:
	Logging.info('TombstoneScreen: exit button pressed, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_continue_pressed() -> void:
	Logging.info('TombstoneScreen._on_continue_pressed: hidden ending continue triggered')
	
	# 1. 设置瞬态信号，通知 main.gd 走隐藏结局继续流程
	GameState.pending_hidden_ending_continue = true
	Logging.info('TombstoneScreen._on_continue_pressed: GameState.pending_hidden_ending_continue = true')
	
	# 2. 解除游戏结束状态锁
	GameState.is_game_over = false
	Logging.info('TombstoneScreen._on_continue_pressed: GameState.is_game_over = false')
	
	# 3. 恢复时间流逝（SystemOperator 在 game_over 时 pause 了）
	TimeService.resume_world()
	Logging.info('TombstoneScreen._on_continue_pressed: TimeService resumed')
	
	# 4. 设置时代为 755_backhome
	GameState.current_era = "755_backhome"
	Logging.info('TombstoneScreen._on_continue_pressed: current_era = 755_backhome')
	
	# 5. 设置时间为 755年10月1日（755 + 9/12 = 755.75）
	TimeService.jump_to(755.75)
	Logging.info('TombstoneScreen._on_continue_pressed: time set to 755/10/1 (year=755.75)')
	
	# 6. 设置初始属性：钱 150，健康 100
	PlayerState.force_set_stat_val("money", 150)
	PlayerState.force_set_stat_val("health", 100)
	Logging.info('TombstoneScreen._on_continue_pressed: money=150, health=100')
	
	# 7. 切换到 main.tscn（main.gd._ready 会检测 pending_hidden_ending_continue 并播放过场）
	Logging.info('TombstoneScreen._on_continue_pressed: changing scene to main.tscn')
	get_tree().change_scene_to_file("res://main.tscn")


func _on_return_to_main_menu() -> void:
	Logging.info('TombstoneScreen: return_to_main_menu signal received, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")


# ════════════════════════════════════════════════════════════════
# 数据填充 — 五个 label 从 PlayerObserver 读取
# ════════════════════════════════════════════════════════════════

const DAYS_PER_YEAR_TOMB: int = 360

func _populate_time_action_rank() -> void:
	var consumption: Dictionary = PlayerObserver.get_all_consumption()
	if consumption.is_empty():
		Logging.info('TombstoneScreen._populate_time_action_rank: consumption_by_identity 为空, label 置空')
		time_action_rank_label.text = ""
		return

	var ranked: Array = []
	for identity in consumption:
		var bucket: Dictionary = consumption[identity]
		var time_spent: int = bucket.get("time", 0)
		if time_spent <= 0:
			continue
		ranked.append({"identity": identity, "time": time_spent, "bucket": bucket})

	if ranked.is_empty():
		Logging.info('TombstoneScreen._populate_time_action_rank: 无 time 消耗记录, label 置空')
		time_action_rank_label.text = ""
		return

	ranked.sort_custom(func(a, b): return a["time"] > b["time"])

	var total_time: int = 0
	for item in ranked:
		total_time += item["time"]

	var top_items: Array = []
	var rest_total_time: int = 0
	var rest_total_money: int = 0
	var rest_total_health: int = 0
	var rest_count: int = 0
	for i in range(ranked.size()):
		if i < 2:
			top_items.append(ranked[i])
		else:
			var item = ranked[i]
			rest_total_time += item["time"]
			rest_total_money += item["bucket"].get("money", 0)
			rest_total_health += item["bucket"].get("health", 0)
			rest_count += 1

	var parts: Array[String] = []
	for i in range(top_items.size()):
		var item = top_items[i]
		var pct: int = int(float(item["time"]) / float(total_time) * 100.0)
		var name_str: String = _resolve_identity_name(item["identity"])
		var bucket: Dictionary = item["bucket"]
		var costs_str: String = _build_cost_string(bucket, ["time"])

		if i == 0:
			if costs_str.is_empty():
				parts.append(tr("TOMB_STONE_TIME_RANK_PRIMARY").format({"pct": pct, "action": name_str}))
			else:
				var costs_wrapped: String = tr("TOMB_STONE_COST_WRAPPER").format({"costs": costs_str})
				parts.append(tr("TOMB_STONE_TIME_RANK_PRIMARY_WITH_COST").format({"pct": pct, "action": name_str, "costs": costs_wrapped}))
		else:
			if costs_str.is_empty():
				parts.append(tr("TOMB_STONE_TIME_RANK_SECONDARY").format({"pct": pct, "action": name_str}))
			else:
				var costs_wrapped: String = tr("TOMB_STONE_COST_WRAPPER").format({"costs": costs_str})
				parts.append(tr("TOMB_STONE_TIME_RANK_SECONDARY_WITH_COST").format({"pct": pct, "action": name_str, "costs": costs_wrapped}))

	if rest_count > 0:
		var rest_pct: int = int(float(rest_total_time) / float(total_time) * 100.0)
		var rest_costs := PackedStringArray()
		if rest_total_money > 0:
			rest_costs.append(tr("TOMB_STONE_COST_ENTRY").format({"amount": rest_total_money, "unit": _prop_display_name("money")}))
		if rest_total_health > 0:
			rest_costs.append(tr("TOMB_STONE_COST_ENTRY").format({"amount": rest_total_health, "unit": _prop_display_name("health")}))
		var rest_costs_str := tr("TOMB_STONE_COST_LIST_SEP").join(rest_costs) if rest_costs.size() > 0 else ""
		if rest_costs_str.is_empty():
			parts.append(tr("TOMB_STONE_TIME_RANK_REST").format({"count": rest_count, "pct": rest_pct}))
		else:
			parts.append(tr("TOMB_STONE_TIME_RANK_REST_WITH_COST").format({"count": rest_count, "pct": rest_pct, "costs": rest_costs_str}))

	time_action_rank_label.text = "".join(parts)
	Logging.info('TombstoneScreen._populate_time_action_rank: %s' % time_action_rank_label.text)


# ════════════════════════════════════════════════════════════════
# SpecificResource — 指定资源消耗分析 + 风味文本
# ════════════════════════════════════════════════════════════════

const PROP_FLAVOR_KEYS: Dictionary = {
	"health": "TOMB_STONE_FLAVOR_HEALTH",
	"money": "TOMB_STONE_FLAVOR_MONEY",
	"prestige": "TOMB_STONE_FLAVOR_PRESTIGE",
	"talent": "TOMB_STONE_FLAVOR_TALENT",
	"time": "TOMB_STONE_FLAVOR_TIME",
	"progress": "TOMB_STONE_FLAVOR_PROGRESS",
	"astuteness": "TOMB_STONE_FLAVOR_ASTUTENESS",
	"composure": "TOMB_STONE_FLAVOR_COMPOSURE",
	"inspiration": "TOMB_STONE_FLAVOR_INSPIRATION",
	"momentum": "TOMB_STONE_FLAVOR_MOMENTUM",
}


func _populate_specific_resource() -> void:
	var prop_name: String = GameState.drained_resource_type
	if prop_name.is_empty():
		Logging.info('TombstoneScreen._populate_specific_resource: drained_resource_type 为空, label 置空')
		specific_resource_label.text = ""
		return

	var consumption: Dictionary = PlayerObserver.get_all_consumption()
	if consumption.is_empty():
		Logging.info('TombstoneScreen._populate_specific_resource: consumption_by_identity 为空, label 置空')
		specific_resource_label.text = ""
		return

	var ranked: Array = []
	for identity in consumption:
		var bucket: Dictionary = consumption[identity]
		var amount: int = bucket.get(prop_name, 0)
		if amount <= 0:
			continue
		ranked.append({"identity": identity, "amount": amount})

	if ranked.is_empty():
		Logging.info('TombstoneScreen._populate_specific_resource: 无 identity 消耗了 %s, label 置空' % prop_name)
		specific_resource_label.text = ""
		return

	ranked.sort_custom(func(a, b): return a["amount"] > b["amount"])

	var prop_display: String = _prop_display_name(prop_name)
	var parts: Array[String] = []

	var rest_amount: int = 0
	for i in range(ranked.size()):
		if i < 2:
			var item = ranked[i]
			var name_str: String = _resolve_identity_name(item["identity"])
			parts.append(tr("TOMB_STONE_SPECIFIC_RESOURCE_ITEM").format({"amount": item["amount"], "unit": prop_display, "action": name_str}))
		else:
			rest_amount += ranked[i]["amount"]

	if rest_amount > 0:
		parts.append(tr("TOMB_STONE_SPECIFIC_RESOURCE_REST").format({"amount": rest_amount, "unit": prop_display}))

	var flavor_key: String = PROP_FLAVOR_KEYS.get(prop_name, "")
	if not flavor_key.is_empty():
		var flavor: String = tr(flavor_key)
		if not flavor.is_empty():
			parts.append(flavor)

	specific_resource_label.text = "".join(parts)
	Logging.info('TombstoneScreen._populate_specific_resource: %s' % specific_resource_label.text)


# ════════════════════════════════════════════════════════════════
# MidwareProduct — 产出统计
# ════════════════════════════════════════════════════════════════

func _populate_midware_product() -> void:
	var poems_count: int = PlayerObserver.get_accumulator("poems_created")
	var friends_count: int = PlayerObserver.get_accumulator("friends_made")
	var ideas_count: int = PlayerObserver.get_accumulator("ideas_accepted")

	if poems_count == 0 and friends_count == 0 and ideas_count == 0:
		Logging.info('TombstoneScreen._populate_midware_product: 三项产出均为 0, label 置空')
		midware_product_label.text = ""
		return

	var parts: Array[String] = []
	if poems_count > 0:
		parts.append(tr("TOMB_STONE_MIDWARE_POEMS").format({"count": poems_count}))
	if friends_count > 0:
		parts.append(tr("TOMB_STONE_MIDWARE_FRIENDS").format({"count": friends_count}))
	if ideas_count > 0:
		parts.append(tr("TOMB_STONE_MIDWARE_IDEAS").format({"count": ideas_count}))

	var sep: String = tr("TOMB_STONE_ITEM_SEPARATOR")
	midware_product_label.text = sep.join(parts) + "。"
	Logging.info('TombstoneScreen._populate_midware_product: %s' % midware_product_label.text)


# ════════════════════════════════════════════════════════════════
# History — 里程碑 + 历史事件
# ════════════════════════════════════════════════════════════════

## total_days 是从公元 0 年开始的绝对天数（与 TimeService._total_days_elapsed 同一量纲）
static func _days_to_date_string(total_days: int) -> String:
	var year: int = total_days / DAYS_PER_YEAR_TOMB
	var day_of_year: int = total_days % DAYS_PER_YEAR_TOMB
	var month: int = day_of_year / 30 + 1
	var day: int = day_of_year % 30 + 1
	return "%d.%d.%d" % [year, month, day]


func _populate_history() -> void:
	var lines: Array[String] = []

	# ── 来源 1: 已达成里程碑 ──
	var milestones: Dictionary = PlayerObserver.get_achieved_milestones()
	var milestone_map: Dictionary = {}
	var config_file := FileAccess.open("res://core/milestones_config.json", FileAccess.READ)
	if config_file:
		var content := config_file.get_as_text()
		config_file.close()
		var parsed = JSON.parse_string(content)
		if parsed and parsed is Dictionary:
			for entry in parsed.get("milestones", []):
				if entry is Dictionary:
					milestone_map[entry.get("key", "")] = entry

	for milestone_key in milestones:
		var data: Dictionary = milestones[milestone_key]
		var achieved_day: int = data.get("achieved_at_day", 0)
		var date_str: String = _days_to_date_string(achieved_day)
		var config: Dictionary = milestone_map.get(milestone_key, {})
		var desc: String = config.get("desc", milestone_key)
		var threshold: int = int(config.get("threshold", 0))

		if threshold <= 1:
			lines.append(tr("TOMB_STONE_HISTORY_MILESTONE_FIRST").format({"date": date_str, "desc": desc}))
		else:
			lines.append(tr("TOMB_STONE_HISTORY_MILESTONE").format({"date": date_str, "desc": desc}))

	if lines.size() > 0:
		lines.sort()

	# ── 来源 2: 历史事件 ──
	var all_history: Dictionary = Database.get_history_events_all()
	if not all_history.is_empty():
		if lines.size() > 0:
			lines.append("")
		var history_items: Array = []
		for uuid in all_history:
			var event: HistoryEvent = all_history[uuid] as HistoryEvent
			if not event:
				continue
			var date_str: String = _days_to_date_string(int(event.target_year * DAYS_PER_YEAR_TOMB))
			var event_name: String = tr(event.name) if not event.name.is_empty() else uuid
			history_items.append(tr("TOMB_STONE_HISTORY_ENTRY").format({"date": date_str, "event": event_name}))
		if history_items.size() > 0:
			history_items.sort()
			lines.append_array(history_items)

	if lines.is_empty():
		Logging.info('TombstoneScreen._populate_history: 无里程碑也无历史事件, label 置空')
		history_label.text = ""
		return

	history_label.text = "\n".join(lines)
	Logging.info('TombstoneScreen._populate_history: %d lines' % lines.size())


# ════════════════════════════════════════════════════════════════
# PoemAssessment — 诗风评价
# ════════════════════════════════════════════════════════════════

const STANCE_ZHUOLIU := "actor:poem:stance:zhuoliu"
const STANCE_QINGLIU := "actor:poem:stance:qingliu"
const STANCE_NEUTRAL := "actor:poem:stance:neutral"

const POEM_ASSESSMENT_KEYS: Dictionary = {
	"none": "TOMB_STONE_POEM_ASSESS_NONE",
	"zhuoliu": "TOMB_STONE_POEM_ASSESS_ZHUOLIU",
	"qingliu": "TOMB_STONE_POEM_ASSESS_QINGLIU",
	"mixed": "TOMB_STONE_POEM_ASSESS_MIXED",
}


func _populate_poem_assessment() -> void:
	var tags: Array[String] = PlayerState.persistant_tags
	var has_zhuoliu: bool = tags.has(STANCE_ZHUOLIU)
	var has_qingliu: bool = tags.has(STANCE_QINGLIU)
	var has_neutral: bool = tags.has(STANCE_NEUTRAL)

	var key: String
	if has_zhuoliu and has_qingliu:
		key = "mixed"
	elif has_zhuoliu:
		key = "zhuoliu"
	elif has_qingliu:
		key = "qingliu"
	elif has_neutral:
		key = "mixed"
	else:
		key = "none"

	var tr_key: String = POEM_ASSESSMENT_KEYS.get(key, "")
	if tr_key.is_empty():
		Logging.info('TombstoneScreen._populate_poem_assessment: 未知 stance key=%s, 保留 tscn 占位' % key)
		return

	var text: String = tr(tr_key)
	if text.is_empty():
		Logging.info('TombstoneScreen._populate_poem_assessment: 翻译 key=%s 返回空, 保留 tscn 占位' % tr_key)
		return

	poem_assessment_label.text = text
	Logging.info('TombstoneScreen._populate_poem_assessment: key=%s tr_key=%s text=%s' % [key, tr_key, text])


# ════════════════════════════════════════════════════════════════
# 辅助函数
# ════════════════════════════════════════════════════════════════

## 将 bucket 中非 skipped 的 prop 拼成 i18n 消耗字符串
func _build_cost_string(bucket: Dictionary, skip_props: Array = []) -> String:
	var entries: PackedStringArray = []
	for prop_name in bucket:
		if prop_name in skip_props:
			continue
		var amount: int = bucket[prop_name]
		if amount <= 0:
			continue
		entries.append(tr("TOMB_STONE_COST_ENTRY").format({"amount": amount, "unit": _prop_display_name(prop_name)}))
	if entries.is_empty():
		return ""
	return tr("TOMB_STONE_COST_LIST_SEP").join(entries)

func _resolve_identity_name(identity: String) -> String:
	var action: Action = Database.get_action(identity) as Action
	if action and not action.name.is_empty():
		return tr(action.name)
	Logging.info('TombstoneScreen._resolve_identity_name: identity=%s 无法通过 Database 解析，使用原值' % identity)
	return identity


func _prop_display_name(prop_name: String) -> String:
	var prop = Database.get_property(prop_name)
	if prop:
		var display = prop.get_display_name()
		if not display.is_empty():
			return display
	return prop_name
