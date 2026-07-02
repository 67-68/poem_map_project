## 统一 Hover 信息面板 — 叙事 + 分隔线 + 向量预览
##
## 上半部分显示叙事文本（action.description / 锁定原因）。
## 下半部分显示向量预览（属性增减箭头 + 前提摘要）。
## 两段同时可见，由 HoverInfoPopup 或 EventBtn._make_custom_tooltip 注入文本。
##
## 由 EventBtn._make_custom_tooltip() 和 SceneActionPanel._register_hover_popup() 创建并注入文本。
extends PanelContainer

## 叙事层标签
var narrative_label: RichTextLabel
## 向量层标签（含 S/M/L 箭头）
var vector_label: RichTextLabel
## 分隔线
var separator: HSeparator
## 外部容器
var _vbox: VBoxContainer

var _narrative_text: String = ""
var _vector_text: String = ""
var _has_vector_data: bool = false

func _init():
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	size_flags_horizontal = SIZE_SHRINK_CENTER

func _ready() -> void:
	# ── 外层 VBox ──
	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	add_child(_vbox)

	# ── 叙事层 RichTextLabel ──
	narrative_label = RichTextLabel.new()
	narrative_label.name = "NarrativeLabel"
	narrative_label.bbcode_enabled = true
	narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_label.custom_minimum_size = Vector2(280, 20)
	narrative_label.fit_content = true
	narrative_label.mouse_filter = MOUSE_FILTER_IGNORE
	_vbox.add_child(narrative_label)

	# ── 分隔线（默认隐藏，有向量数据时再显示）──
	separator = HSeparator.new()
	separator.name = "Separator"
	separator.mouse_filter = MOUSE_FILTER_IGNORE
	separator.visible = false
	_vbox.add_child(separator)

	# ── 向量层 RichTextLabel ──
	vector_label = RichTextLabel.new()
	vector_label.name = "VectorLabel"
	vector_label.bbcode_enabled = true
	vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vector_label.custom_minimum_size = Vector2(280, 20)
	vector_label.fit_content = true
	vector_label.mouse_filter = MOUSE_FILTER_IGNORE
	vector_label.visible = false
	_vbox.add_child(vector_label)

	# ── 应用文本 ──
	if not _narrative_text.is_empty():
		narrative_label.text = _narrative_text
	if not _vector_text.is_empty():
		vector_label.text = _vector_text
		_has_vector_data = true
		separator.visible = true
		vector_label.visible = true


## 设置叙事层文本（行动描述 / 锁定原因）
func set_narrative_text(text: String) -> void:
	_narrative_text = text
	if narrative_label:
		narrative_label.text = text

## 设置向量层文本（属性增减箭头 + 前提摘要）
func set_vector_text(text: String) -> void:
	_vector_text = text
	_has_vector_data = not text.is_empty()
	if vector_label:
		vector_label.text = text
		vector_label.visible = _has_vector_data
	if separator:
		separator.visible = _has_vector_data
