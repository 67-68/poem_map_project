@tool
class_name ImagenaryItem extends PanelContainer

@onready var rich: RichTextLabel = $M/Rich
var current_style: StyleBoxFlat
@export var imaginary_tag: ImaginaryTag

signal imagenery_item_clicked(item: ImagenaryItem)
signal comprehend_requested(item: ImagenaryItem)

func _ready():
	# 检测点击
	gui_input.connect(_on_gui_input)

func _exit_tree():
	if imaginary_tag:
		imaginary_tag.level_changed.disconnect(_on_level_changed)
		imaginary_tag.tier_changed.disconnect(_on_tier_changed)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_delete_one_fragment()
			return
		if event.double_click:
			if can_comprehend():
				comprehend_requested.emit(self)
			return
		imagenery_item_clicked.emit(self)

func can_comprehend() -> bool:
	if not imaginary_tag:
		return false
	return imaginary_tag.basic_imaginaries.size() >= ImaginaryTag.l2_threshold

func _delete_one_fragment():
	if not imaginary_tag:
		return
	if imaginary_tag.basic_imaginaries.size() > 0:
		imaginary_tag.basic_imaginaries.pop_front()
		EventBus.imaginary_changed.emit()

func _init():
	pass

func init(ima: ImaginaryTag):
	imaginary_tag = ima
	setup_visuals(ima.current_level, ima.name)
	imaginary_tag.level_changed.connect(_on_level_changed)
	imaginary_tag.tier_changed.connect(_on_tier_changed)

func _on_level_changed(new_level: int):
	setup_visuals(new_level, imaginary_tag.name)

func _on_tier_changed(_new_tier: int):
	setup_visuals(imaginary_tag.current_level, imaginary_tag.name)

# 极其务实的动态样式生成器
func setup_visuals(level: int, text_content: String):
	current_style = StyleBoxFlat.new()
	current_style.bg_color = Color(0, 0, 0, 0.4) # 统一的半透明底色
	
	var tier := 0
	if imaginary_tag:
		tier = imaginary_tag.current_tier
	
	var comprehend_prefix := ""
	var can_comp := can_comprehend()
	if can_comp:
		comprehend_prefix = "✨ "

	match level:
		1: # L1
			current_style.border_width_bottom = 1
			current_style.border_color = Color(0.5, 0.5, 0.5, 0.5)
			$M/Rich.text = "[color=#888888]%s%s[/color]" % [comprehend_prefix, text_content]
		2: # L2
			current_style.set_border_width_all(1)
			current_style.border_color = Color.WHITE
			$M/Rich.text = "%s%s" % [comprehend_prefix, text_content]
		3: # L3
			current_style.set_border_width_all(1)
			current_style.border_color = Color.RED
			# 开启终极发光 Hack
			current_style.shadow_color = Color(1.0, 0.0, 0.0, 0.6)
			current_style.shadow_size = 8
			$M/Rich.text = "[shake rate=20 level=5][color=red]%s%s[/color][/shake]" % [comprehend_prefix, text_content]

	# ── Tier 视觉叠加 ──────────────────────────────────
	match tier:
		3: # 高洁：金色边框 + 金色 shadow
			current_style.border_color = Color.GOLD
			current_style.shadow_color = Color.GOLD
			current_style.shadow_size = 6
		2: # 沉重：银灰边框 + 暗色 shadow
			current_style.border_color = Color.SLATE_GRAY
			current_style.shadow_color = Color(0.2, 0.2, 0.2, 0.6)
			current_style.shadow_size = 4
		1: # 污染：暗绿/破败色调
			current_style.border_color = Color(0.3, 0.4, 0.2, 0.7)
			current_style.shadow_color = Color(0.1, 0.15, 0.05, 0.5)
			current_style.shadow_size = 2
		_: # 0 (未坍缩)：保持 level-only 样式，不覆盖
			pass

	# 感悟可用时的绿色边框提示（覆盖 tier 颜色）
	if can_comp:
		current_style.border_color = Color.GREEN
		current_style.shadow_color = Color.GREEN
		current_style.shadow_size = 4

	# 将生成的样式动态赋给根节点
	self.add_theme_stylebox_override("panel", current_style)

func get_text():
	return $M/Rich.text
