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

	# TimeActionRank / SpecificResource / MidwareProduct / History / PoemAssessment
	# 保持 tscn 内的占位文本。后续由玩家数据管道（PlayerObserver）填入实际内容。
	Logging.info('TombstoneScreen._populate_label_texts: done — remaining labels use tscn placeholders')


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

	# Step 9: 显示返回按钮
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

func _on_button_pressed() -> void:
	Logging.info('TombstoneScreen: exit button pressed, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_return_to_main_menu() -> void:
	Logging.info('TombstoneScreen: return_to_main_menu signal received, returning to main menu')
	get_tree().change_scene_to_file("res://main_menu.tscn")
