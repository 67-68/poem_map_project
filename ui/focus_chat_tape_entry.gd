class_name FocusChatTapeEntry extends VBoxContainer
## 纸带密谈笔录 — 名章+对话文本，左/右对齐，点击翻页，选项在尾
##
## 文本渲染：使用 RichTextLabel（支持 BBCode 标记），
## 可通过 description 字段传入 [color][b][i] 等标签。

signal dialogue_finished(result: ChoiceResult)

var _dialogue_sequence: Array = []
var _current_index: int = 0
var _context: Dictionary = {}
var _chat_data: FocusedChat = null
var _choice_created: bool = false
var _option_btns: OptionBtns = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)
	if _chat_data and _dialogue_sequence.size() > 0:
		_show_current_line()


func play_dialogue_sequence(dialogues: FocusedChat, context: Dictionary = {}) -> void:
	_chat_data = dialogues
	_context = context.duplicate(true)
	_dialogue_sequence = dialogues.chats
	_current_index = 0
	_choice_created = false

	# 如果还没 ready 就等 ready 后再展示
	if not is_node_ready():
		await ready
		if not is_inside_tree():
			return

	_show_current_line()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if _choice_created:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect = get_global_rect()
		if rect.has_point(event.position):
			get_viewport().set_input_as_handled()
			_current_index += 1
			_show_current_line()


func _show_current_line() -> void:
	if _current_index >= _dialogue_sequence.size():
		# 对话播完 → 显示选项（如有）
		if _chat_data and _chat_data.options.size() > 0 and not _choice_created:
			Logging.info("FocusChatTapeEntry: 对话播完，options 数量=%d" % _chat_data.options.size())
			for i in range(_chat_data.options.size()):
				var opt = _chat_data.options[i]
				Logging.info("FocusChatTapeEntry:   options[%d] description='%s' _resolved='%s'" % [i, opt.description if 'description' in opt else 'N/A', opt._resolved_description if '_resolved_description' in opt and opt._resolved_description else 'N/A'])
				opt.init(_context)
			_show_options()
			_choice_created = true
		else:
			# 无选项自动结束
			dialogue_finished.emit(null)
			return

		var line: FocusedChatLine = _dialogue_sequence[_current_index]
		_append_dialogue_line(line)
		line.execute_operators(_context)


func _append_dialogue_line(line: FocusedChatLine) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if line.chat_position == FocusedChatLine.ChatPosition.LEFT:
		_setup_left_line(hbox, line)
	else:
		_setup_right_line(hbox, line)

	add_child(hbox)


func _setup_left_line(hbox: HBoxContainer, line: FocusedChatLine) -> void:
	# 1. 名章: 36x36 红色方印 + 姓氏白字
	var seal := Label.new()
	seal.text = _get_surname(line.name)
	seal.custom_minimum_size = Vector2(36, 36)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_color_override("font_color", Color.WHITE)
	seal.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.70, 0.12, 0.12)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.50, 0.08, 0.08)
	seal.add_theme_stylebox_override("normal", style)

	# 2. 说话人姓名（暗红色）
	var name_lbl := Label.new()
	name_lbl.text = line.name
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.25, 0.25))
	name_lbl.add_theme_font_size_override("font_size", 16)

	# 3. 对话文本（NarrativeText theme variant）— 使用 RichTextLabel 支持 BBCode
	var text_lbl := RichTextLabel.new()
	text_lbl.text = line.description
	text_lbl.theme_type_variation = "NarrativeText"
	text_lbl.fit_content = true
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	hbox.add_child(seal)
	hbox.add_child(name_lbl)
	hbox.add_child(text_lbl)


func _setup_right_line(hbox: HBoxContainer, line: FocusedChatLine) -> void:
	hbox.alignment = BoxContainer.ALIGNMENT_END

	# 1. 对话文本（NarrativeText theme variant）— 右对齐（印章在右，文本需与右侧视觉连贯）
	var text_lbl := RichTextLabel.new()
	# RichTextLabel 不支持 alignment 属性，改用 BBCode [right] 标签实现右对齐
	text_lbl.bbcode_enabled = true
	text_lbl.text = "[right]" + line.description + "[/right]"
	text_lbl.theme_type_variation = "NarrativeText"
	text_lbl.fit_content = true
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 2. 说话人姓名（墨色）
	var name_lbl := Label.new()
	name_lbl.text = line.name
	name_lbl.add_theme_color_override("font_color", Color(0.29, 0.22, 0.15))
	name_lbl.add_theme_font_size_override("font_size", 16)

	# 3. 笔锋/名章前缀 — 使用墨色小方块
	var brush := Label.new()
	brush.text = _get_surname(line.name)
	brush.custom_minimum_size = Vector2(36, 36)
	brush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brush.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brush.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.23, 0.18, 0.12)
	bstyle.border_width_left = 2
	bstyle.border_width_right = 2
	bstyle.border_width_top = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = Color(0.15, 0.12, 0.08)
	brush.add_theme_stylebox_override("normal", bstyle)

	hbox.add_child(text_lbl)
	hbox.add_child(name_lbl)
	hbox.add_child(brush)


func _show_options() -> void:
	Logging.info("FocusChatTapeEntry: _show_options 被调用")
	_option_btns = preload("res://ui/option_btns.tscn").instantiate()
	add_child(_option_btns)
	_option_btns.apply_btns(_chat_data.options, _on_option_selected)


func _on_option_selected(choice_result: ChoiceResult) -> void:
	var chosen_text := _find_chosen_text(choice_result)
	Logging.info("FocusChatTapeEntry: 选项已选「%s」，发出 dialogue_finished" % chosen_text)

	# ── "既决"烙印 ──
	# 格式：「 既决：<选项文本> 」
	# 暗朱砂红 + 极淡麻纸底色 + 微弱红色下划线 + 左缩进 20px + 上下双倍间距
	var chosen_lbl := Label.new()
	chosen_lbl.text = tr("CODE_SETTLEMENT_TAPE_ENTRY_46A78AC7C9") % chosen_text
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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	# VBoxContainer separation=12，额外加 12px 使上下总间距 = 24px
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(chosen_lbl)
	add_child(margin)

	dialogue_finished.emit(choice_result)


func _find_chosen_text(choice_result: ChoiceResult) -> String:
	""tr("CODE_FOCUS_CHAT_TAPE_ENTRY_32FCFCFD75")""
	for opt in _chat_data.options:
		if opt.choice_result == choice_result:
			var txt = opt._resolved_description if '_resolved_description' in opt and opt._resolved_description else opt.description
			return txt
	return "?"


func _get_surname(name: String) -> String:
	# 取姓氏（第一个字即可作为印章内容）
	if name.length() > 0:
		return name[0]
	return "?"
