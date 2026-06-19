extends VBoxContainer
class_name DecisionPanel

@export var decision: Decision

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

func _init() -> void:
	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = HOVER_BG_COLOR
	_normal_style = StyleBoxEmpty.new()

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func inititalization(decision_: Decision):
	decision = decision_
	$ActionPanel/V/TitleLabel.text = decision_.name
	$ActionPanel/V/DescriptionLabel.text = decision_.description
	
	# ── Hover 底色绑定 ──
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# ── Hover Popup（Alt 双层揭示）──
	if not decision_.description.is_empty() or not decision_.action_results.is_empty() or not decision_.aciton_requirements.is_empty():
		_register_hover_popup()


## 创建 HoverInfoPopup，注入叙事文本 + 向量文本，注册到 HoverPopupManager
func _register_hover_popup() -> void:
	var popup := HoverInfoPopup.new()
	
	# 叙事层（默认可见）
	popup.set_narrative_text(decision.description if not decision.description.is_empty() else "（无叙述）")
	
	# 向量层（Alt 按下可见）
	var vector_lines: Array[String] = []
	if not decision.aciton_requirements.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 前提 ━━━[/font_size][/color]")
		for req in decision.aciton_requirements:
			var desc = req.describe_requirement()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	if not decision.action_results.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
		for op in decision.action_results:
			var desc = op.describe_preview()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	popup.set_vector_text("\n".join(vector_lines))
	
	HoverPopupManager.register(self, popup, 0.5, 0.15)


func _on_mouse_entered() -> void:
	if _hover_style and not _hover_style.bg_color == Color.TRANSPARENT:
		self.add_theme_stylebox_override("normal", _hover_style)


func _on_mouse_exited() -> void:
	self.add_theme_stylebox_override("normal", _normal_style)
	


func _on_button_pressed() -> void:
	for r in decision.action_results:
		r.operate()
	decision.disabled = true
