# GalgameOverlay.gd
extends Control

@onready var left_portrait = $MarginContainer/LeftCharacter
@onready var right_portrait = $MarginContainer/RightCharacter
@onready var text_label = $MarginContainer/Panel/VBox/ChatLabel
@onready var name_label = $MarginContainer/Panel/VBox/NameLabel

var _dialogue_sequence: Array = []
var _current_index: int = 0
var choice_created := false
var use_choice := false
var data: FocusedChat

signal chat_finished(result: ChoiceResult)

func play_dialogue_sequence(dialogues: FocusedChat): # array of focusChat
    data = dialogues
    # 这里没有第一时间加载，是缓冲的问题？
    _dialogue_sequence = dialogues.chats as Array
    $Background.texture = dialogues.icon
    _current_index = 0
    $MarginContainer/VBoxContainer/Title.text = dialogues.name
    $MarginContainer/VBoxContainer/Description.text = dialogues.description

    if data.get("options"):
        use_choice = true

    _show_current_line()
    find_texture()

func find_texture():
    if not $MarginContainer/LeftCharacter.texture:
        for dia in _dialogue_sequence:
            if dia.texture and dia.chat_position == FocusedChatLine.ChatPosition.LEFT:
                $MarginContainer/LeftCharacter.texture = dia.texture
                break
    if not $MarginContainer/RightCharacter.texture:
        for dia in _dialogue_sequence:
            if dia.texture and dia.chat_position == FocusedChatLine.ChatPosition.RIGHT:
                $MarginContainer/RightCharacter.texture = dia.texture
                break

# 在切换说话人时，加一个微微向上弹跳的动画
func _bounce_portrait(portrait_node: TextureRect):
    var tween = create_tween()
    # 瞬间往上抬 15 像素，然后花 0.2 秒落回来 (带回弹效果)
    tween.tween_property(portrait_node, "position:y", -15.0, 0.05).as_relative()
    tween.tween_property(portrait_node, "position:y", 15.0, 0.2).as_relative().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# 接管点击事件，用来翻页
func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # ⚠️ 防弹装甲 1：如果选项已经弹出来了，绝对、立刻吞掉屏幕点击事件！
        # 逼着玩家去点按钮，不准他们再点屏幕翻页！
        if choice_created:
            return 
            
        get_viewport().set_input_as_handled()
        _current_index += 1
        _show_current_line()

# 核心渲染流转
func _show_current_line():
    if not is_node_ready(): await ready

    # 1. 终点判定：是不是已经没话说了？
    if _current_index >= _dialogue_sequence.size():
        if use_choice and not choice_created:
            # 展现选项，并立刻打断渲染逻辑！
            $MarginContainer/OptionBtns.visible = true
            # 把 try_end_dialogue 作为 Callable 传给按钮，让按钮被点时调用它
            $MarginContainer/OptionBtns.apply_btns(data.options, try_end_dialogue)
            choice_created = true
        else:
            # 没话说了，而且本来就没选项，直接黯然退场
            try_end_dialogue(null)
            
        return # ⚠️ 架构师的警告：一定要在这里 return！绝对不能让代码往下走到 var line！

    # 2. 如果还没到终点，正常渲染当句对白
    var line = _dialogue_sequence[_current_index]
    
    name_label.text = line.name
    text_label.text = line.description
    
    var tex = line.texture if line.texture else null 
    
    if line.chat_position == FocusedChatLine.ChatPosition.LEFT:
        left_portrait.texture = tex
        _bounce_portrait(left_portrait)
        left_portrait.modulate = Color(1, 1, 1, 1) 
        right_portrait.modulate = Color(0.5, 0.5, 0.5, 1) 
    else:
        right_portrait.texture = tex
        _bounce_portrait(right_portrait)
        right_portrait.modulate = Color(1, 1, 1, 1)
        left_portrait.modulate = Color(0.5, 0.5, 0.5, 1)

# 专属善后部 (只由按钮点击，或无选项结束时调用)
func try_end_dialogue(choice_result = null):
    Global.bubble_complete.emit()
    chat_finished.emit(choice_result) # 把结果传回给 UIManager
    queue_free()
