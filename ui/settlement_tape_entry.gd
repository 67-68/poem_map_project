class_name SettlementTapeEntry extends PanelContainer

## SettlementTapeEntry — 月末结算专用纸带条目
## 布局：PanelContainer(暗朱边框) → VBoxContainer → [HSeparator, Label(标题), HSeparator, RichTextLabel(内容), HSeparator, Button(合上考评)]

signal option_selected(choice_result, choice_text: String)

var _title_label: Label
var _content_rtl: RichTextLabel
var _confirm_btn: Button
var _layout_ready := false


func _ready() -> void:
	_ensure_layout()
	_connect_signals()


## 确保布局已构造（幂等：多次调用只构造一次）
func _ensure_layout() -> void:
	if _layout_ready:
		return
	_purge_existing_children()
	_construct_layout()
	_layout_ready = true


## 清除编辑器中可能预置的子节点，确保纯代码构造
func _purge_existing_children() -> void:
	for child in get_children():
		child.queue_free()


func _construct_layout() -> void:
	# ── 暗朱边框 StyleBox ──
	var style := StyleBoxFlat.new()
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.border_color = Color("#8B0000")
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	# ── 内部 VBoxContainer ──
	var vbox := VBoxContainer.new()
	vbox.name = "VBox_Layout"
	add_child(vbox)

	# ── HSeparator 1 ──
	var sep1 := HSeparator.new()
	sep1.name = "Sep1"
	sep1.theme_type_variation = "SeparatorTheme"
	vbox.add_child(sep1)

	# ── 标题 Label ──
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.theme_type_variation = "TitleText"
	_title_label.add_theme_color_override(&"font_color", NarrativeOverlay.DIM_HISTORY_INK_COLOR)
	vbox.add_child(_title_label)

	# ── HSeparator 2 ──
	var sep2 := HSeparator.new()
	sep2.name = "Sep2"
	sep2.theme_type_variation = "SeparatorTheme"
	vbox.add_child(sep2)

	# ── 内容 RichTextLabel ──
	_content_rtl = RichTextLabel.new()
	_content_rtl.name = "ContentRichText"
	_content_rtl.bbcode_enabled = true
	_content_rtl.scroll_active = false
	_content_rtl.clip_contents = false
	_content_rtl.fit_content = true
	_content_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_rtl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content_rtl.theme_type_variation = "NarrativeText"
	_content_rtl.add_theme_color_override(&"default_color", NarrativeOverlay.DIM_HISTORY_INK_COLOR)
	vbox.add_child(_content_rtl)

	# ── HSeparator 3 ──
	var sep3 := HSeparator.new()
	sep3.name = "Sep3"
	sep3.theme_type_variation = "SeparatorTheme"
	vbox.add_child(sep3)

	# ── OptionBtns 容器（event_ui.mark_chosen 依赖此节点名） ──
	var option_btns := HBoxContainer.new()
	option_btns.name = "OptionBtns"
	vbox.add_child(option_btns)

	# ── 确认按钮 "合上考评" ──
	_confirm_btn = Button.new()
	_confirm_btn.name = "ConfirmBtn"
	_confirm_btn.text = "合上考评"
	_confirm_btn.theme_type_variation = "ButtonTheme"
	option_btns.add_child(_confirm_btn)


func _connect_signals() -> void:
	if _confirm_btn:
		_confirm_btn.pressed.connect(_on_confirm_pressed)


func populate(event: BaseEvent) -> void:
	Logging.info("SettlementTapeEntry.populate: event='%s' _layout_ready=%s" % [event.name, _layout_ready])

	# 🔒 防御：populate 可能早于 _ready() 被调用（add_child 前），
	#     此时 _title_label / _content_rtl 尚未构造。先强制初始化。
	_ensure_layout()

	if _title_label:
		_title_label.text = event.name
		Logging.info("SettlementTapeEntry.populate: title_label 已设置 = '%s'" % event.name)
	else:
		Logging.err("SettlementTapeEntry.populate: _title_label 为 null，无法设置标题")

	if _content_rtl:
		_content_rtl.text = event.description
		Logging.info("SettlementTapeEntry.populate: content_rtl 已设置（%d 字符）" % event.description.length())
	else:
		Logging.err("SettlementTapeEntry.populate: _content_rtl 为 null，无法设置内容")

	if _confirm_btn and event.options.size() > 0:
		_confirm_btn.text = event.options[0].description

	Logging.info("SettlementTapeEntry.populate: 结算条目已填充完毕")


func _on_confirm_pressed() -> void:
	Logging.info("SettlementTapeEntry: '合上考评' 被点击，原地构造 PopEventOperator")
	var result := ChoiceResult.new()
	result.operators = [PopEventOperator.new()]
	option_selected.emit(result, "合上考评")
