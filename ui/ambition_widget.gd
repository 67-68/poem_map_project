class_name AmbitionWidget extends VBoxContainer

@onready var toggle_btn: Button = $ToggleBtn
@onready var content_panel: TextureRect = $AmbitionHUD

func _ready() -> void:
    # 强制初始折叠，保持界面干净
    PlayerState.ambition_changed.connect(func():
        if PlayerState.ambition:
            toggle_btn.text = PlayerState.ambition.name
    )
    content_panel.visible = false
    toggle_btn.pressed.connect(_on_toggle_pressed)
    
    # ── 音效挂件注入 ──
    var SfxCls := preload("res://features/ui_sound_component.gd")
    var sfx := SfxCls.new()
    sfx.name = "UISoundComponent"
    sfx.click_category = "book_impact"
    toggle_btn.add_child(sfx)


func _on_toggle_pressed() -> void:
    # 🤓☝️ 唯一的核心逻辑：布尔值翻转！
    # VBoxContainer 会自动处理所有的排版挤压，一帧内完成，绝不报错！
    content_panel.visible = !content_panel.visible
