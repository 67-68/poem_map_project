@tool
class_name ImagenaryItem extends PanelContainer

@onready var rich: RichTextLabel = $M/Rich
var current_style: StyleBoxFlat

signal imagenery_item_clicked(item: ImagenaryItem)

func _ready():
	# 检测点击
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		#breakpoint
		imagenery_item_clicked.emit(self)

func _init():
	pass

func init(ima: ImaginaryTag):
	setup_visuals(ima.current_level, ima.name)

# 极其务实的动态样式生成器
func setup_visuals(level: int, text_content: String):
	current_style = StyleBoxFlat.new()
	current_style.bg_color = Color(0, 0, 0, 0.4) # 统一的半透明底色
	
	match level:
		1: # L1
			current_style.border_width_bottom = 1
			current_style.border_color = Color(0.5, 0.5, 0.5, 0.5)
			$M/Rich.text = "[color=#888888]%s[/color]" % text_content
		2: # L2
			current_style.set_border_width_all(1)
			current_style.border_color = Color.WHITE
			$M/Rich.text = text_content
		3: # L3
			current_style.set_border_width_all(1)
			current_style.border_color = Color.RED
			# 开启终极发光 Hack
			current_style.shadow_color = Color(1.0, 0.0, 0.0, 0.6) 
			current_style.shadow_size = 8
			$M/Rich.text = "[shake rate=20 level=5][color=red]%s[/color][/shake]" % text_content
			
	# 将生成的样式动态赋给根节点
	self.add_theme_stylebox_override("panel", current_style)

func get_text():
	return $M/Rich.text
