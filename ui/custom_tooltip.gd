## 双层 CustomTooltip - Alt Reveal 工具提示
##
## 默认显示叙事层文本（锁定原因/内心挣扎）。
## 按住 Alt 键时切换为向量层文本（operator 预览 + requirement 摘要）
## 释放 Alt 键后恢复叙事层。
##
## 由 EventBtn._make_custom_tooltip() 实例化并注入文本。
extends PanelContainer

## 叙事层标签（默认可见，Alt 按下时半透明）
var narrative_label: RichTextLabel
## 向量层标签（默认隐藏，Alt 按下时可见）
var vector_label: RichTextLabel

## 叙事层半透明 alpha（Alt 按下时）
const NARRATIVE_FADE_ALPHA: float = 0.3
## 叙事层全透明度的 tween 持续时间（秒）
const FADE_DURATION: float = 0.15

var _narrative_text: String = ""
var _vector_text: String = ""
var _alt_pressed: bool = false

func _init():
	# 确保工具提示在所有暂停状态下都能工作
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	size_flags_horizontal = SIZE_SHRINK_CENTER

func _ready() -> void:
	# ── 叙事层 RichTextLabel ──
	narrative_label = RichTextLabel.new()
	narrative_label.name = "NarrativeLabel"
	narrative_label.bbcode_enabled = true
	narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_label.custom_minimum_size = Vector2(280, 0)
	narrative_label.fit_content = true
	narrative_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(narrative_label)

	# ── 向量层 RichTextLabel ──
	vector_label = RichTextLabel.new()
	vector_label.name = "VectorLabel"
	vector_label.bbcode_enabled = true
	vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vector_label.custom_minimum_size = Vector2(280, 0)
	vector_label.fit_content = true
	vector_label.mouse_filter = MOUSE_FILTER_IGNORE
	vector_label.visible = false
	add_child(vector_label)

	# ── 应用文本 ──
	if not _narrative_text.is_empty():
		narrative_label.text = _narrative_text
	if not _vector_text.is_empty():
		vector_label.text = _vector_text


func _process(_delta: float) -> void:
	# 每帧检测 Alt 键状态
	var alt_down = Input.is_key_pressed(KEY_ALT)
	if alt_down == _alt_pressed:
		return  # 状态未变化

	_alt_pressed = alt_down
	if alt_down:
		# Alt 按下：叙事层褪色，向量层可见
		narrative_label.modulate.a = NARRATIVE_FADE_ALPHA
		vector_label.visible = true
	else:
		# Alt 松开：叙事层恢复，向量层隐藏
		narrative_label.modulate.a = 1.0
		vector_label.visible = false


## 设置叙事层文本（锁定原因/内心挣扎）
func set_narrative_text(text: String) -> void:
	_narrative_text = text
	if narrative_label:
		narrative_label.text = text

## 设置向量层文本（operator 预览 + requirement 摘要）
func set_vector_text(text: String) -> void:
	_vector_text = text
	if vector_label:
		vector_label.text = text
