extends Control

var target_node: Node2D
var base_offset: Vector2 = Vector2(0, -60) # 悬浮在头顶的像素偏移量

@onready var label = $Panel/Marg/Label
var mode: POS_MODE

enum POS_MODE {
    NODE_ATTATCHMENT,
    POSITION
}

func _ready():
    # 动画演出：从小到大弹出来，增加灵动感
    scale = Vector2.ZERO
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(_delta):
    # 1. 生命线检测：如果诗人死了/被刷掉了，气泡立刻自杀！
    if not is_instance_valid(target_node):
        queue_free()
        return
    on_change_pos()

func on_change_pos():    
    match mode:
        POS_MODE.NODE_ATTATCHMENT:
            # 2. 坐标降维打击：世界坐标 -> 屏幕 UI 坐标 (Godot 神级 API)
            # 无论你的 Camera2D 怎么平移、缩放，气泡永远死死钉在诗人头顶的屏幕位置！
            var screen_pos = target_node.get_global_transform_with_canvas().origin
            position = screen_pos + base_offset
        POS_MODE.POSITION:
            pass

# 供外部 (缓冲池) 调用的初始化接口
func setup(data: ChatBubble):
    label.text = data.description
    if data.attached_node:
        target_node = data.attached_node
        mode = POS_MODE.NODE_ATTATCHMENT
    elif data.position:
        mode = POS_MODE.POSITION
        position = data.position

# 3. 接管全局点击：Galgame 祖传手艺
func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # 吞掉这次点击，防止点到地图背后的州府
        get_viewport().set_input_as_handled() 
        
        # 告诉我们之前写的 UI 缓冲池：玩家看完了，进行下一个！
        # 假设你的 UIManager 单例里持有 bubble_buffer
        Global.bubble_complete.emit()
        
        # 销毁自己
        queue_free()