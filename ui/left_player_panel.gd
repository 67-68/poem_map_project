extends PanelContainer

# 记录 UI 初始的锚点位置（绝对真理）
var _original_pos_x: float
var _is_animating: bool = false
var _is_visible_state: bool = true # 记录逻辑上的可见性

# 动画滑动的距离
const SLIDE_OFFSET: float = 50.0 
const ANIM_DURATION: float = 0.3

func _ready() -> void:
    $V/NameLabel.text = PlayerState.player_name
    $V/PlayerRect.texture = TextureResLoader.get_icon_simpler(PlayerState.player_name)
    TimeService.on_xun_tick.connect(func():
        update_dynamic_data()
    )
    EventBus.request_change_left_panel_visibility.connect(func():
        if _is_visible_state:
            hide_panel()
        else:
            show_panel()
    )

    _record_original_position() # 没有container, 不需要call_deferred

func update_dynamic_data():
    # 更新玩家名称
    if PlayerState.ambition:
        $V/AmbitionLabel.text = '野心' + PlayerState.ambition.name + '\n' 
        $V/AmbitionLabel.text += PlayerState.ambition.get_stage_perception()
    
    var text = 'props: \n'
    for s in Database.get_properties_all():
        text += "%s: %s\n" % [s, Database.get_property(s).val]
        text += 'stage-percep: %s\n' % Database.get_property(s).get_staged_perception_text()
    $V/Scroll/V/PropLabel.text = text

    # 展示所有trait
    var trait_text = 'traits: \n'
    for t in PlayerState.traits:
        trait_text += "- %s\n" % t
    $V/Scroll/V/TraitLabel.text = trait_text

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
