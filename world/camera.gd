extends Camera2D

@export_group("大唐时空视界控制")
@export var min_zoom: float = 0.3   # 大地图极远
@export var max_zoom: float = 2.0   # 城市街道极近
@export var zoom_speed: float = 0.2 # 缩放步长

# 🤓☝️ 核心架构：设定一个极其明确的跨维度阈值！
# 当缩放大于这个值时，视为进入城市；小于等于这个值，退回大地图
@export var city_threshold: float = 1.2 

var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# 将目标缩放值缓存起来，避免 Tween 过程中的浮点数扰动
var _target_zoom: float = 1.0 
var _current_state: String = 'world'

func _ready() -> void:
    print("🎥 [DebugCamera] 已上线. 滚轮缩放，右键/中键拖拽，Q键复位。")
    enabled = true
    _target_zoom = zoom.x

func _unhandled_input(event: InputEvent) -> void:
    # 1. 缩放控制 (滚轮)
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _apply_zoom(zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _apply_zoom(-zoom_speed)
    
    # 2. 拖拽状态开关 (右键/中键)
    if event is InputEventMouseButton:
        if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
            if event.pressed:
                _dragging = true
                _last_mouse_pos = event.position
            else:
                _dragging = false

    # 3. 丝滑拖拽逻辑
    if event is InputEventMouseMotion and _dragging:
        var delta = event.position - _last_mouse_pos
        # 必须除以当前的缩放倍率，否则放大时拖拽会像光速一样飞走 💀
        position -= delta / zoom.x 
        _last_mouse_pos = event.position

    # 4. 快捷键复位
    if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
        position = Vector2.ZERO
        _target_zoom = 1.0
        _apply_zoom(0) # 传入 0 只触发复位补间和状态检查

# 统一的缩放与状态分发引擎
func _apply_zoom(amount: float) -> void:
    # 限制目标缩放值在合法范围内
    _target_zoom = clamp(_target_zoom + amount, min_zoom, max_zoom)
    
    # 丝滑补间动画
    var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
    tween.tween_property(self, "zoom", Vector2(_target_zoom, _target_zoom), 0.2)
    
    # 🌟 维度打击：精确的状态流转
    var new_state = 'city' if _target_zoom >= city_threshold else 'world'
    
    if new_state != _current_state:
        _current_state = new_state
        # 发射信号给 UI 和 渲染层
        Global.focus_city_map.emit(_current_state == 'city')
        print("🎥 视界已切换至: ", _current_state)
