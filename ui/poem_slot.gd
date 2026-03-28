class_name PoemSlot extends PanelContainer

@export var item_occupying: ImagenaryItem = null
signal slot_clicked(slot: PoemSlot)

func apply_style(style: StyleBoxFlat):
    self.add_theme_stylebox_override("panel", style)

func apply_text(text):
    $C/RichTextLabel.text = text

func _ready():
    # 检测点击
    gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        slot_clicked.emit(self)