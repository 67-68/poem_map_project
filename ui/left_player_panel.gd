extends PanelContainer

# 记录 UI 初始的锚点位置（绝对真理）
var _original_pos_x: float
var _is_animating: bool = false
var _is_visible_state: bool = true # 记录逻辑上的可见性

# 动画滑动的距离
const SLIDE_OFFSET: float = 50.0 
const ANIM_DURATION: float = 0.3

func _ready() -> void:
    # 💀 核心防呆：如果这个 Panel 放在 VBox/HBox 这种容器里，
    # 它的 position 会在第一帧被引擎排版强行接管！
    # 所以我们用 call_deferred 确保在排版完成后再记录它的真实坐标。
    call_deferred("_record_original_position")
    
    Global.request_change_left_panel_visibility.connect(func():
        if _is_visible_state:
            hide_panel()
        else:
            show_panel()
    )

func _record_original_position():
    _original_pos_x = position.x

# 消失：从当前（右）向左滑动，并渐隐
func hide_panel():
    if _is_animating or not _is_visible_state: return
    _is_animating = true
    _is_visible_state = false
    
    var tween = create_tween()
    # 🤓☝️ 极其优雅的并行与缓动曲线
    tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    
    # 往左移动 SLIDE_OFFSET，同时透明度变为 0
    tween.tween_property(self, "position:x", _original_pos_x - SLIDE_OFFSET, ANIM_DURATION)
    tween.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
    
    # 动画彻底结束后，再把它从渲染树中物理剔除（防止阻挡鼠标点击）
    tween.chain().tween_callback(func():
        visible = false
        _is_animating = false
    )

# 展示：从左向右滑回原位，并渐显
func show_panel():
    if _is_animating or _is_visible_state: return
    _is_animating = true
    _is_visible_state = true
    
    # 💀 必须先显示出来！否则后面的动画全是在虚空中播放！
    visible = true 
    
    var tween = create_tween()
    tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    
    # 🤓☝️ 这就是你要的 .from() 魔法：
    # 指定目标为原位/不透明，但要求引擎从 (原位-偏移量) 和 (完全透明) 开始动画！
    tween.tween_property(self, "position:x", _original_pos_x, ANIM_DURATION).from(_original_pos_x - SLIDE_OFFSET)
    tween.tween_property(self, "modulate:a", 1.0, ANIM_DURATION).from(0.0)
    
    tween.chain().tween_callback(func(): _is_animating = false)
