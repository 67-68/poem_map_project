class_name PoemSlot extends PanelContainer
## V8: 纯展示控件 — 不再有点击交互，仅用于展示 Imaginary 名称

@export var item_occupying = null ## 占用该 Slot 的 Imaginary（或溢出时设为特殊标记）

func apply_style(style: StyleBoxFlat):
    self.add_theme_stylebox_override("panel", style)

func apply_text(text):
    $C/RichTextLabel.text = text

func set_greyed(greyed: bool) -> void:
    if greyed:
        $C/RichTextLabel.modulate = Color(0.4, 0.4, 0.4, 1.0)
        $C/RichTextLabel.add_theme_color_override("default_color", Color(0.4, 0.4, 0.4, 1.0))
    else:
        $C/RichTextLabel.modulate = Color(1, 1, 1, 1)
        $C/RichTextLabel.remove_theme_color_override("default_color")

func _ready():
    mouse_filter = MOUSE_FILTER_IGNORE
    if $C.has_method("set_mouse_filter"):
        $C.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if $C/RichTextLabel.has_method("set_mouse_filter"):
        $C/RichTextLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
