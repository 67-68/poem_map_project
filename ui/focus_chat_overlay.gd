# GalgameOverlay.gd
extends Control

@onready var left_portrait = $MarginContainer/LeftCharacter
@onready var right_portrait = $MarginContainer/RightCharacter
@onready var text_label = $MarginContainer/Panel/VBox/ChatLabel
@onready var name_label = $MarginContainer/Panel/VBox/NameLabel

var _dialogue_sequence: Array = []
var _current_index: int = 0
var choice_created := false
var data: FocusedChat

func play_dialogue_sequence(dialogues: FocusedChat): # array of focusChat
    # 这里没有第一时间加载，是缓冲的问题？
    _dialogue_sequence = dialogues.chats as Array
    $Background.texture = dialogues.icon
    _current_index = 0
    _show_current_line()

# 在切换说话人时，加一个微微向上弹跳的动画
func _bounce_portrait(portrait_node: TextureRect):
    var tween = create_tween()
    # 瞬间往上抬 15 像素，然后花 0.2 秒落回来 (带回弹效果)
    tween.tween_property(portrait_node, "position:y", -15.0, 0.05).as_relative()
    tween.tween_property(portrait_node, "position:y", 15.0, 0.2).as_relative().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _show_current_line():
    if not is_node_ready(): await ready
    try_end_dialogue()
        
    var line = _dialogue_sequence[_current_index]
    
    $MarginContainer/Panel/VBox/NameLabel.text = line.name
    $MarginContainer/Panel/VBox/ChatLabel.text = line.description
    
    # 动态加载并替换立绘 (利用 Godot 的缓存，这里极快)
    var tex = line.texture if line.texture else null # 我的数据渲染管线在之前load好了
    
    if line.chat_position == FocusedChatLine.ChatPosition.LEFT:
        left_portrait.texture = tex
        _bounce_portrait(left_portrait)
        left_portrait.modulate = Color(1, 1, 1, 1) # 说话的人高亮
        right_portrait.modulate = Color(0.5, 0.5, 0.5, 1) # 不说话的人变暗
    else:
        right_portrait.texture = tex
        _bounce_portrait(right_portrait)
        right_portrait.modulate = Color(1, 1, 1, 1)
        left_portrait.modulate = Color(0.5, 0.5, 0.5, 1)

func try_end_dialogue():
    if _current_index >= _dialogue_sequence.size():
        # 播完了！销毁自己，触发 UIManager 里的 tree_exited 信号，队列继续！

        if not choice_created:
            $MarginContainer/OptionBtns.apply_btns(data.options,try_end_dialogue)
            choice_created = true # 这里其实可以把这个状态封装到option btns(is_created)

        Global.bubble_complete.emit()
        queue_free()
        return 

# 接管点击事件，用来翻页
func _input(event):
    if $MarginContainer/OptionBtns.visible and choice_created: return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        get_viewport().set_input_as_handled()
        _current_index += 1
        _show_current_line()
