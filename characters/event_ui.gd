class_name EventUI extends PanelContainer

## 纸带管理器：极乐迪斯科式事件纸带（Append-only Tape）
##
## 职责：
## - 管理 ScrollContainer → VBox_TapeContent 内的 TapeEntry 生命周期
## - Event 条目：完整的标题/正文/选项区，选后选项变文本烙印
## - dim / clear_all_dim 控制前序条目的可见性
##
## 契约：
## - entry_id 由 NarrativeOverlay 侧传入（事件 instance_id）
## - 信号 option_selected(choice_result, choice_text) 桥接回 NarrativeOverlay
signal option_selected(choice_result, choice_text: String)
## SLOW 模式打字机全部阶段完成时发射（告知 NarrativeOverlay 可以启动 auto-advance Timer）
signal display_complete


# ── 打字机参数 ──────────────────────────────────
const SLOW_SPEED: float = 0.04
const SLOWEST_SPEED: float = 0.08
const PHASE_PAUSE: float = 0.6

# ── dim 颜色 ──────────────────────────────────
const DIM_COLOR: Color = Color(0.35, 0.35, 0.35, 1.0)
const NORMAL_COLOR: Color = Color.WHITE


# ── 子节点引用 ──────────────────────────────────
@onready var _tape_content: VBoxContainer = $Margin/ScrollContainer/VBox_TapeContent
@onready var _scroll: SmoothScrollContainer = $Margin/ScrollContainer

# ── Event 条目模板 ─────────────────────────────
var _event_template: PackedScene = preload("res://ui/event_ui.tscn")

# ── 打字机状态 ──────────────────────────────────
var _skip_requested: bool = false
var _current_timer: Timer = null

# ── 当前活跃条目追踪 ────────────────────────────
var _active_entry_id: String = ""


# ═══════════════════════════════════════════════
# 初始化
# ═══════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return


# ═══════════════════════════════════════════════
# 公共 API — 纸带条目生命周期
# ═══════════════════════════════════════════════

## 追加一个 Event 条目到纸带底部
## entry_id: 稳定标识符（事件 instance_id），用于 has_entry / mark_chosen
## 返回创建的 TapeEntry 节点，供 display_slow 打字机写入（FAST 模式用不到返回值）
func append_event_entry(event: BaseEvent, all_options: Array, context: Dictionary, from_stack: bool, entry_id: String):
	Logging.info("EventUI.append_event_entry: event='%s' entry_id='%s' from_stack=%s" % [event.name, entry_id, from_stack])

	var entry = _event_template.instantiate()
	_apply_event_icon(event, entry)
	entry.set_meta("entry_id", entry_id)
	entry.set_meta("entry_type", "event")
	entry.set_meta("state", "awaiting_choice")
	entry.set_meta("from_stack", from_stack)

	# 子节点引用
	var title_label: Label = entry.get_node("MarginContainer/VBox/HBox/TitleLabel")
	var content_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ContentLabel")
	var example_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ExampleLabel")
	var option_btns: Control = entry.get_node("MarginContainer/VBox/OptionBtns")

	# 填充内容
	title_label.text = event.name
	content_label.text = Util.tr_and_resolve(event.description, context, event)
	if event.example.is_empty():
		example_label.hide()
	else:
		example_label.text = event.example

	# ── UIDecl 颜色应用 ──
	_apply_ui_decl_colors(event, title_label, content_label)

	# 选项按钮 → 信号桥接（携带选项文本用于纸带烙印）
	option_btns.apply_btns(all_options, func(r):
		var txt := _find_option_text(all_options, r)
		Logging.info("EventUI: 选项被选中，转发 option_selected 信号（entry_id='%s' text='%s'）" % [entry_id, txt])
		option_selected.emit(r, txt)
	)

	_tape_content.add_child(entry)
	_active_entry_id = entry_id

	Logging.info("EventUI.append_event_entry: 条目已追加到纸带（entry_id='%s'）" % entry_id)
	return entry




## 追加 pop 回归条目到纸带底部 — 仅选项按钮，不渲染 title/content/example
## 旧条目的 "即决：xxx" 烙印保留在历史位置，底部新增空白选项
func append_pop_regression_entry(event: BaseEvent, all_options: Array, entry_id: String) -> void:
	Logging.info("EventUI.append_pop_regression_entry: event='%s' entry_id='%s'" % [event.name, entry_id])

	var entry = _event_template.instantiate()
	_apply_event_icon(event, entry)
	entry.set_meta("entry_id", entry_id)
	entry.set_meta("entry_type", "event")
	entry.set_meta("state", "awaiting_choice")
	entry.set_meta("from_stack", true)
	entry.set_meta("pop_regression", true)

	# 隐藏 title / content / example — pop 回归不需重复渲染正文
	var title_label: Label = entry.get_node("MarginContainer/VBox/HBox/TitleLabel")
	var content_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ContentLabel")
	var example_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ExampleLabel")
	title_label.hide()
	content_label.hide()
	example_label.hide()

	# 仅渲染选项按钮
	var option_btns: Control = entry.get_node("MarginContainer/VBox/OptionBtns")
	option_btns.apply_btns(all_options, func(r):
		var txt := _find_option_text(all_options, r)
		Logging.info("EventUI: pop回归选项被选中，转发 option_selected 信号（entry_id='%s' text='%s'）" % [entry_id, txt])
		option_selected.emit(r, txt)
	)

	_tape_content.add_child(entry)
	_active_entry_id = entry_id

	Logging.info("EventUI.append_pop_regression_entry: pop回归条目已追加（entry_id='%s'）" % entry_id)

## 追加结算条目到纸带（绕过常规打字机，直接全量显示）
func append_settlement_entry(event: BaseEvent, context: Dictionary) -> void:
	Logging.info("EventUI.append_settlement_entry: event='%s'" % event.name)

	var entry: SettlementTapeEntry = preload("res://ui/settlement_tape_entry.tscn").instantiate()
	entry.set_meta("entry_id", str(event.get_instance_id()))
	entry.set_meta("entry_type", "settlement")

	entry.populate(event)
	entry.option_selected.connect(func(choice_result, choice_text):
		option_selected.emit(choice_result, choice_text)
	)

	_tape_content.add_child(entry)
	_active_entry_id = str(event.get_instance_id())
	scroll_to_bottom()
	Logging.info("EventUI.append_settlement_entry: 结算条目已追加到纸带")


## 追加一个 Stub 条目（Cinematic / Picker / FocusChat 播完后的纯文本摘要）
func append_stub(stub_type: String, summary_text: String) -> void:
	Logging.info("EventUI.append_stub: type='%s' text='%s'" % [stub_type, summary_text])

	var stub := Label.new()
	stub.text = summary_text
	stub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stub.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3, 1.0))
	stub.add_theme_font_size_override("font_size", 14)

	# 斜体风格提示这是摘要，而非正式事件
	stub.set_meta("entry_type", "stub")
	stub.set_meta("stub_type", stub_type)

	_tape_content.add_child(stub)
	Logging.info("EventUI.append_stub: stub 已追加到纸带")


## 追加 FocusChat 密谈笔录到纸带 — 名章+对话逐行，点击翻页
## 返回 FocusChatTapeEntry 实例，供 NarrativeOverlay 连接 dialogue_finished 信号
func append_focus_chat_entry(data: FocusedChat, context: Dictionary = {}) -> FocusChatTapeEntry:
	Logging.info("EventUI.append_focus_chat_entry: chat='%s'" % data.name)

	var entry := preload("res://ui/focus_chat_tape_entry.tscn").instantiate()
	_tape_content.add_child(entry)

	# 延迟一帧让节点进入场景树，然后开始播放
	call_deferred("_start_focus_chat", entry, data, context)

	return entry


func _start_focus_chat(entry: FocusChatTapeEntry, data: FocusedChat, context: Dictionary) -> void:
	if not is_instance_valid(entry):
		return
	entry.play_dialogue_sequence(data, context)
	scroll_to_bottom()


## 追加 Picker 呈堂物证到纸带 — 木牍/令牌网格，选后定格
## 返回 PickerTapeAttachment 实例，供 NarrativeOverlay 连接 item_selected 信号
func append_picker_attachment(data: Array, ui_constructor: Callable = Callable()) -> PickerTapeAttachment:
	Logging.info("EventUI.append_picker_attachment: items=%d" % data.size())

	var attachment := preload("res://ui/picker_tape_attachment.tscn").instantiate()
	_tape_content.add_child(attachment)
	attachment.initialize(data, ui_constructor)

	call_deferred("scroll_to_bottom")

	return attachment


## 检查纸带上是否已有指定 entry_id 的条目
func has_entry(entry_id: String) -> bool:
		for child in _tape_content.get_children():
			if child.has_meta("entry_id") and child.get_meta("entry_id") == entry_id:
				return true
		return false

## 追加一个 NarrativeText 条目到纸带底部
## 用于 pop_event 回归时的过渡叙事文本（transition_text + on_returned 合并）
## 使用 RichTextLabel + theme_type_variation="NarrativeText"，支持 BBCode
func append_narrative_text(text: String) -> void:
	if text.is_empty():
		Logging.debug("EventUI.append_narrative_text: 文本为空，跳过")
		return
	Logging.info("EventUI.append_narrative_text: text='%s'" % text)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = text
	rtl.theme_type_variation = "NarrativeText"
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	rtl.set_meta("entry_type", "narrative_text")

	_tape_content.add_child(rtl)
	Logging.info("EventUI.append_narrative_text: NarrativeText 条目已追加到纸带")



## 标记条目为已选择：选项按钮销毁 → 文本烙印
func mark_chosen(entry_id: String, choice_text: String) -> void:
	Logging.info("EventUI.mark_chosen: entry_id='%s' choice='%s'" % [entry_id, choice_text])

	var entry := _find_entry(entry_id)
	if not entry:
		Logging.err("EventUI.mark_chosen: 未找到 entry_id='%s'" % entry_id)
		return

	var state: String = entry.get_meta("state", "")
	if state != "awaiting_choice":
		Logging.warn("EventUI.mark_chosen: entry_id='%s' 状态为 '%s'（非 awaiting_choice），跳过" % [entry_id, state])
		return

	# 1. 隐藏选项按钮
	var option_btns: Control = entry.get_node("MarginContainer/VBox/OptionBtns")
	option_btns.hide()

	# 2. 创建文本烙印 "「 既决：XXX 」"（古典格式）
	var chosen_lbl := Label.new()
	chosen_lbl.name = "ChoiceLabel"
	chosen_lbl.text = "「 既决：%s 」" % choice_text
	chosen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chosen_lbl.add_theme_color_override("font_color", Color(0.55, 0.10, 0.10))
	chosen_lbl.add_theme_font_size_override("font_size", 14)

	# 极淡麻纸底色 + 微弱红色下划线
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.96, 0.93, 0.86, 0.20)
	bg_style.border_width_left = 0
	bg_style.border_width_right = 0
	bg_style.border_width_top = 0
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.55, 0.10, 0.10, 0.25)
	chosen_lbl.add_theme_stylebox_override("normal", bg_style)

	# 左缩进 20px + 上下双倍间距（通过 MarginContainer 实现）
	# 必须加入 VBox 而非根 PanelContainer — PanelContainer 不会垂直堆叠子节点
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(chosen_lbl)
	var vbox := entry.get_node("MarginContainer/VBox") as VBoxContainer
	if vbox:
		vbox.add_child(margin)
	else:
		entry.add_child(margin)

	entry.set_meta("state", "chosen")
	entry.set_meta("chosen_text", choice_text)

	if _active_entry_id == entry_id:
		_active_entry_id = ""

	Logging.info("EventUI.mark_chosen: entry_id='%s' 已标记为 chosen" % entry_id)


# ═══════════════════════════════════════════════
# 公共 API — dim 策略
# ═══════════════════════════════════════════════

## 将纸带上最后一个条目之前的所有条目设为暗灰色
func dim_previous_entries() -> void:
	var children := _tape_content.get_children()
	if children.size() <= 1:
		Logging.debug("EventUI.dim_previous_entries: 纸带上只有 %d 个条目，跳过 dim" % children.size())
		return

	for i in range(children.size() - 1):
		var child = children[i]
		if child is CanvasItem:
			child.modulate = DIM_COLOR

	Logging.info("EventUI.dim_previous_entries: 已 dim %d 个条目" % (children.size() - 1))


## 将纸带上所有条目恢复为正常颜色
func clear_all_dim() -> void:
	var count := 0
	for child in _tape_content.get_children():
		if child is CanvasItem:
			child.modulate = NORMAL_COLOR
			count += 1
	Logging.info("EventUI.clear_all_dim: 已恢复 %d 个条目的颜色" % count)


## 清空整个纸带（移除所有 TapeEntry 节点）
func clear_all_tape() -> void:
	for child in _tape_content.get_children():
		child.queue_free()
	_active_entry_id = ""
	Logging.info("EventUI.clear_all_tape: 纸带已清空")


# ═══════════════════════════════════════════════
# 公共 API — 滚动
# ═══════════════════════════════════════════════

## 滚动到纸带底部（等下一帧布局计算完成后）
func scroll_to_bottom() -> void:
	await get_tree().process_frame
	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll:
		v_scroll.value = v_scroll.max_value
		Logging.debug("EventUI.scroll_to_bottom: 已滚动到底部")


## 滚动到指定 entry_id 的条目位置
func scroll_to_entry(entry_id: String) -> void:
	await get_tree().process_frame
	var entry := _find_entry(entry_id)
	if not entry:
		Logging.warn("EventUI.scroll_to_entry: 未找到 entry_id='%s'" % entry_id)
		return

	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll:
		var target_y: float = 0.0
		for child in _tape_content.get_children():
			if child == entry:
				break
			if child is Control:
				target_y += child.size.y + _tape_content.get_theme_constant("separation")

		v_scroll.value = target_y
		Logging.debug("EventUI.scroll_to_entry: 已滚动到 entry_id='%s' (y=%.1f)" % [entry_id, target_y])


# ═══════════════════════════════════════════════
# 公共 API — 打字机
# ═══════════════════════════════════════════════

## SLOW / SLOWEST 模式：打字机逐阶段写入 TapeEntry 的标签
func display_slow(event: BaseEvent, all_options: Array, context: Dictionary, from_stack: bool, entry_id: String, type_speed: float = SLOW_SPEED) -> void:
	Logging.info("EventUI.display_slow: 模式开始事件 '%s'（type_speed=%.3f）" % [event.name, type_speed])
	AudioManager.play_sfx_category("book_place")

	# Step 1: 创建空骨架 TapeEntry（不含正文和选项）
	var entry = _event_template.instantiate()
	_apply_event_icon(event, entry)
	entry.set_meta("entry_id", entry_id)
	entry.set_meta("entry_type", "event")
	entry.set_meta("state", "awaiting_choice")
	entry.set_meta("from_stack", from_stack)

	var title_label: Label = entry.get_node("MarginContainer/VBox/HBox/TitleLabel")
	var content_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ContentLabel")
	var example_label: RichTextLabel = entry.get_node("MarginContainer/VBox/ExampleLabel")
	var option_btns: Control = entry.get_node("MarginContainer/VBox/OptionBtns")

	title_label.text = ""
	# ── UIDecl 颜色应用 ──
	_apply_ui_decl_colors(event, title_label, content_label)

	content_label.text = ""
	example_label.text = ""
	option_btns.hide()

	_tape_content.add_child(entry)
	_active_entry_id = entry_id
	_skip_requested = false

	# Step 2: Phase 1 — Title 打字机
	Logging.debug("EventUI.display_slow: Phase 1 — Title 打字机开始")
	await _typewrite_phase(title_label, event.name, type_speed)
	Logging.debug("EventUI.display_slow: Phase 1 — Title 完成")

	# Step 3: Phase 2 — Description 打字机
	Logging.debug("EventUI.display_slow: Phase 2 — Description 打字机开始")
	var desc: String = Util.tr_and_resolve(event.description, context, event)
	await _typewrite_phase(content_label, desc, type_speed)
	Logging.debug("EventUI.display_slow: Phase 2 — Description 完成")

	# Step 4: Phase 3 — Example（可选）
	if not event.example.is_empty():
		Logging.debug("EventUI.display_slow: Phase 3 — Example 打字机开始")
		await _typewrite_phase(example_label, event.example, type_speed)
		Logging.debug("EventUI.display_slow: Phase 3 — Example 完成")
	else:
		example_label.hide()
		Logging.debug("EventUI.display_slow: Phase 3 — example 为空，跳过")

	# Step 5: Phase 4 — 显示选项
	Logging.info("EventUI.display_slow: Phase 4 — 显示选项（%d 个）" % all_options.size())
	option_btns.show()
	option_btns.apply_btns(all_options, func(r):
		var txt := _find_option_text(all_options, r)
		Logging.info("EventUI: SLOW 模式选项被选中，转发 option_selected 信号（entry_id='%s' text='%s'）" % [entry_id, txt])
		option_selected.emit(r, txt)
	)
	Logging.info("EventUI.display_slow: 事件 '%s' 显示完成" % event.name)
	display_complete.emit()


# ═══════════════════════════════════════════════
# 打字机基础设施
# ═══════════════════════════════════════════════

func _typewrite_phase(label: Control, full_text: String, type_speed: float = SLOW_SPEED) -> void:
	_skip_requested = false

	# Phase 0: 先全量填充文本撑开 label，测量并锁定最小高度，防止打字过程中 layout 抖动
	label.text = full_text
	await get_tree().process_frame  # 等一帧让 RichTextLabel 完成 bbcode/换行排版
	label.custom_minimum_size.y = label.size.y
	label.text = ""

	await _typewrite(label, full_text, type_speed)
	if _skip_requested:
		Logging.debug("EventUI: 阶段被用户跳过，进入短暂停留")
	else:
		Logging.debug("EventUI: 阶段自然播完，进入短暂停留")
	await _wait(PHASE_PAUSE)


func _typewrite(label: Control, full_text: String, speed: float) -> void:
	if speed <= 0.0 or full_text.is_empty():
		Logging.debug("EventUI._typewrite: speed=%f 或文本为空，直接填充" % speed)
		label.text = full_text
		return

	# 预分词：将 BBCode 标签块（如 [glitch]...[/glitch]）整体识别为原子段
	var segments := _tokenize_bbcode(full_text)
	var displayed := ""
	var literal_char_count := 0  # 仅统计普通文本字符，用于音效节拍

	for seg in segments:
		if _skip_requested:
			Logging.debug("EventUI._typewrite: 检测到 skip，填充全文（%d 字）" % full_text.length())
			label.text = full_text
			return

		if seg["is_bbcode"]:
			# BBCode 块：整体一次性输出
			displayed += seg["text"]
			label.text = displayed
			AudioManager.play_sfx_category("ink_flip", 0.08)
			await _wait(speed)
			if _skip_requested:
				Logging.debug("EventUI._typewrite: wait 后检测到 skip，填充全文")
				label.text = full_text
				return
		else:
			# 普通文本：逐字符打字
			var lit: String = seg["text"]
			for j in range(lit.length()):
				if _skip_requested:
					Logging.debug("EventUI._typewrite: 检测到 skip，填充全文（%d 字）" % full_text.length())
					label.text = full_text
					return
				displayed += lit[j]
				label.text = displayed
				# 每 3 字播放一次吐字音效，避免音频泛滥
				if literal_char_count % 3 == 0:
					AudioManager.play_sfx_category("ink_flip", 0.08)
				literal_char_count += 1
				await _wait(speed)
				if _skip_requested:
					Logging.debug("EventUI._typewrite: wait 后检测到 skip，填充全文")
					label.text = full_text
					return


## 将文本预切割为 literal 段和 bbcode 段。
## 返回 Array[Dictionary]，每个元素 {"is_bbcode": bool, "text": String}
func _tokenize_bbcode(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var i := 0
	var current_literal := ""

	while i < text.length():
		if text[i] == "[":
			var close_bracket := text.find("]", i)
			if close_bracket == -1:
				# 没有闭合 ]，当作普通字符
				current_literal += text[i]
				i += 1
				continue

			var tag_section := text.substr(i + 1, close_bracket - i - 1)

			# 跳过闭合标签如 [/glitch] —— 它已经在块匹配中被消费，不应单独出现
			if tag_section.begins_with("/"):
				current_literal += text[i]
				i += 1
				continue

			# 提取标签名（空格前或 ] 前）
			var space_idx := tag_section.find(" ")
			var tag_name: String
			if space_idx == -1:
				tag_name = tag_section
			else:
				tag_name = tag_section.substr(0, space_idx)

			if tag_name.is_empty():
				current_literal += text[i]
				i += 1
				continue

			# 搜索匹配的闭合标签 [/tag_name]
			var closing_tag := "[/%s]" % tag_name
			var closing_idx := text.find(closing_tag, close_bracket + 1)

			if closing_idx == -1:
				# 没有匹配闭合标签，当作普通字符
				current_literal += text[i]
				i += 1
				continue

			# 完整 BBCode 块
			var bbcode_text := text.substr(i, closing_idx + closing_tag.length() - i)

			# 提交累积的普通文本
			if not current_literal.is_empty():
				result.append({"is_bbcode": false, "text": current_literal})
				current_literal = ""

			result.append({"is_bbcode": true, "text": bbcode_text})
			i = closing_idx + closing_tag.length()
		else:
			current_literal += text[i]
			i += 1

	# 提交剩余的普通文本
	if not current_literal.is_empty():
		result.append({"is_bbcode": false, "text": current_literal})

	return result


func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.start()
	_current_timer = timer
	await timer.timeout
	_current_timer = null
	timer.queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _skip_requested:
			Logging.debug("EventUI: 用户左键点击，跳过当前打字机阶段")
			AudioManager.play_sfx_category("book_flip")
		_skip_requested = true
		if _current_timer:
			_current_timer.wait_time = 0.0


# ═══════════════════════════════════════════════
# 内部工具方法
# ═══════════════════════════════════════════════

## 在纸带上按 entry_id 查找条目
func _find_entry(entry_id: String) -> Control:
	for child in _tape_content.get_children():
		if child.has_meta("entry_id") and child.get_meta("entry_id") == entry_id:
			return child
	return null


## 从选项数组中寻找匹配 ChoiceResult 的选项，返回其显示文本
## choice_result 是 EventBtn.option_made 发出的 ChoiceResult（从 option.choice_result 获取）
## 通过反向查找数组找到对应的 BaseOption，取其 text
func _find_option_text(all_options: Array, choice_result) -> String:
	if not choice_result:
		return "?"
	for o in all_options:
		if not o is BaseOption:
			continue
		var o_choice_result = o.get("choice_result")
		if o_choice_result != null and o_choice_result == choice_result:
			# 🚨 GDScript 4: get() 不返回以下划线开头的变量。
			# EventOption._resolved_description 是 transient 字段（非 @export），
			# 需通过直接属性访问或类型判断后读取。
			if o is EventOption and not o._resolved_description.is_empty():
				return o._resolved_description
			return o.description
	return "?"


# ═══════════════════════════════════════════════
# 内部工具方法 — 纹理
# ═══════════════════════════════════════════════

## 根据事件的 ui_decl 应用 title/content 颜色覆盖
func _apply_ui_decl_colors(event: BaseEvent, title_label: Label, content_label: RichTextLabel) -> void:
	if not event.ui_decl:
		return
	var ui_decl: UIDecl = event.ui_decl
	# Title 文字颜色：color_of_title_text 同时用于标题和内容
	if not ui_decl.color_of_title_text.is_empty():
		var title_color := UIDecl.resolve_color(ui_decl.color_of_title_text, 'title')
		if title_color != Color():
			title_label.add_theme_color_override(&"font_color", title_color)
			content_label.add_theme_color_override(&"default_color", title_color)
			Logging.info("EventUI._apply_ui_decl_colors: event='%s' title/content color=%s" % [event.name, ui_decl.color_of_title_text])


## 根据事件的 icon 字段动态设置背景纹理和透明度
## 使用 tscn 中预定义的 TextureRect 子节点（已设置 layout_mode=2）
func _apply_event_icon(event: BaseEvent, entry: PanelContainer) -> void:
	var bg: TextureRect = entry.get_node("TextureRect")
	if not bg:
		Logging.warn("EventUI._apply_event_icon: entry 内未找到 TextureRect 子节点，跳过背景设置")
		return

	var tex: Texture2D
	var alpha: float
	var stretch: int
	if event.icon != null:
		tex = event.icon
		alpha = 0.25
		stretch = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		Logging.debug("EventUI._apply_event_icon: 设置 icon 纹理 (alpha=0.25, keep_aspect) for '%s'" % event.name)
	else:
		tex = load("res://assets/maps/宣纸.jpeg")
		alpha = 0.10
		stretch = TextureRect.STRETCH_SCALE
		Logging.debug("EventUI._apply_event_icon: 回退到默认宣纸纹理 (alpha=0.10, scale) for '%s'" % event.name)

	bg.stretch_mode = stretch
	bg.texture = tex
	bg.self_modulate.a = alpha

	# 赛博雕版 Shader：仅在有自定义 icon 纹理时启用二值化效果
	# 回退到默认宣纸时不挂载 shader，保留原始麻纸纹理的柔和感
	_apply_woodcut_shader(bg, event.icon != null)


## 按纹理有无动态挂载/卸载 woodcut_binary 二值化 shader
## has_icon: true → 启用雕版效果；false → 清除 shader 还原原始纹理
func _apply_woodcut_shader(bg: TextureRect, has_icon: bool) -> void:
	if has_icon:
		var mat := bg.material as ShaderMaterial
		if not mat or mat.shader == null:
			mat = ShaderMaterial.new()
			mat.shader = load("res://shaders/woodcut_binary.gdshader")
			mat.set_shader_parameter("threshold", 0.5)
			mat.set_shader_parameter("ink_color", Color(0.0, 0.0, 0.0, 0.85))
			mat.set_shader_parameter("paper_color", Color(1.0, 1.0, 1.0, 0.0))
			bg.material = mat
			Logging.debug("EventUI._apply_woodcut_shader: 已挂载 woodcut shader")
	else:
		bg.material = null
		Logging.debug("EventUI._apply_woodcut_shader: 无自定义 icon，已清除 shader")


# ═══════════════════════════════════════════════
# InputManager 桥接 — 纸带滚动容器
# ═══════════════════════════════════════════════

func register_scroll_for_input_manager() -> void:
	"""注册纸带 ScrollContainer，供 InputManager 处理 PgUp/PgDn"""
	var im := _get_input_manager()
	if not im:
		Logging.warn("EventUI.register_scroll_for_input_manager: 无法获取 InputManager")
		return
	im.register_scroll_container(_scroll)


func _get_input_manager() -> InputManager:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return null
	var core_systems := main_node.get_node_or_null("CoreSystems")
	if not core_systems:
		return null
	return core_systems.get_node_or_null("InputManager") as InputManager
