# GalgameOverlay.gd
extends Control

@onready var left_portrait = $LeftCharacter
@onready var right_portrait = $RightCharacter
@onready var text_label = $Panel/Vbox/ChatLabel
@onready var name_label = $Panel/Vbox/NameLabel

var _dialogue_sequence: Array = []
var _current_index: int = 0

func play_dialogue_sequence(dialogues): # array of focusChat
    # 这里没有第一时间加载，是缓冲的问题？
    _dialogue_sequence = dialogues.chats as Array
    _current_index = 0
    _show_current_line()

func _show_current_line():
    if not is_node_ready(): await ready
    if _current_index >= _dialogue_sequence.size():
        # 播完了！销毁自己，触发 UIManager 里的 tree_exited 信号，队列继续！
        Global.bubble_complete.emit()
        queue_free()
        return
        
    var line = _dialogue_sequence[_current_index]
    
    $Panel/VBox/NameLabel.text = line.name
    $Panel/VBox/ChatLabel.text = line.description
    
    # 动态加载并替换立绘 (利用 Godot 的缓存，这里极快)
    var tex = line.texture if line.texture else null # 我的数据渲染管线在之前load好了
    
    if line.chat_position == FocusedChatLine.ChatPosition.LEFT:
        left_portrait.texture = tex
        left_portrait.modulate = Color(1, 1, 1, 1) # 说话的人高亮
        right_portrait.modulate = Color(0.5, 0.5, 0.5, 1) # 不说话的人变暗
    else:
        right_portrait.texture = tex
        right_portrait.modulate = Color(1, 1, 1, 1)
        left_portrait.modulate = Color(0.5, 0.5, 0.5, 1)

# 接管点击事件，用来翻页
func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        get_viewport().set_input_as_handled()
        _current_index += 1
        _show_current_line()
