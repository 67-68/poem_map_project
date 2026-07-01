extends Node
const _AnimationObject = preload("res://model/animation_object.gd")
const _Decision = preload("res://core/model/decision.gd")
const _DecisionScroll = preload("res://ui/decision_scroll.gd")
const _FloatingText = preload("res://world/floating_text.gd")
const _NarrativeOverlay = preload("res://characters/narrative_overlay.gd")
const _SceneAction = preload("res://core/model/scene_action.gd")
const _SceneActionScroll = preload("res://ui/scene_action_scroll.gd")
const _SimpleToast = preload("res://world/simple_toast.gd")
const _SystemOperator = preload("res://core/operators/system_operator.gd")
const _TombstoneScreen = preload("res://ui/tomb_stone_screen.gd")

signal user_click_map(data: Variant)

signal place_holder()
signal user_clicked(data: Variant)
signal request_start_black(enable: bool)

# ── 飘字/通知系统信号 ───────────────────────────────────
# [新] 屏幕 UI 飘字 (FloatingText)
# content: 模糊文本 (支持 BBCode), 如 "[color=#FFD700]塞外风情[/color]"
# 自动定位到屏幕顶部居中，无需传入位置参数
signal request_float_text(content: String)
# [新] UI Toast (合并 SimpleToast + pop_up)
# content: 文本内容
# type: 0=普通提示, 1=警告
signal request_toast(content: String, type: int)
# ────────────────────────────────────────────────────────

# @deprecated 改用 request_toast(content, 0)
signal request_text_popup(text: String)
# @deprecated 改用 request_toast(content, 1)
signal request_warning_toast(data: String)

signal request_rain(enable: bool)
signal request_daylight(enable: bool)

signal year_changed(year: float)
signal speed_changed(speed: float)

signal poems_created(data: Array)
signal request_apply_poem(data: Variant, poet: Variant)
signal poem_animation_finished()

signal request_add_messager(msg: Variant)
signal request_change_bg_modulate(color: Color)
signal request_restore_bg_modulate(duration: float)
signal event_confirmed()

signal request_change_left_panel_visibility(enable)
signal request_toggle_map_only()
signal request_toggle_debug_overlay()
signal request_toggle_debug_controller()
signal request_event(data: Variant, context: Dictionary)
signal request_event_key(key: String, context: Dictionary)
signal push_event(data: Variant, context: Dictionary)
## pop_event — 弹出栈顶事件，回到栈中下一个事件
## transition_text: 回归时打印的过渡文本（可选，传 "" 向后兼容）
## 该文本会与目标事件的 on_returned 属性合并打印为 NarrativeText 条目
## ⚠️ GDScript 信号参数不支持默认值，调用方必须显式传 "" 以保持兼容
signal pop_event(transition_text: String)
signal pop_to_event(event_key: String)
signal clear_scheduled_events()
signal bubble_complete()
signal request_add_chat(data: Variant)

# --- FocusChat 栈条目（仿 Picker/Cinematic 模式）--------
signal push_focused_chat(data: Variant, context: Dictionary)    # 触发方 → NarrativeOverlay: 推入栈（含 context）

signal request_advance_time(days: int)

signal focus_city_map(enable: bool)
signal selected_actions_change(actions: Array)
## 锁定行动被选中时广播，携带被锁定的 SceneAction 数组
## ActionMap 监听此信号对按钮施加闪光效果
signal locked_actions_selected(actions: Array)
## 请求 SceneActionScroll 刷新行动面板（事件链结束后恢复 UI 状态）
signal request_refresh_action_panel()
## 🆕 请求刷新 action 锁定状态（不重新抽取，仅更新灰化/解锁状态）
## 由 ActionManager.reevaluate_all_locks() 在属性变动时发射。
signal request_refresh_action_locks()
## Focus session 状态变更（true=进入聚焦模式，false=退出）
## 用于 right_info_panel 等 UI 组件隐藏/显示非行动元素（如写诗按钮）
signal focus_session_changed(active: bool)
signal avaialble_decision_change(decision)

## 任意 Decision 被点击时触发，用于 DecisionScroll 即时刷新
signal decision_clicked()

signal show_tombstone_screen(death_reason: String)
## 请求返回主菜单（由 SystemOperator.return_main 触发，TombstoneScreen 监听）
signal request_return_to_main_menu()
signal event_shown(event: Variant)
signal poem_start_clicked()
signal poem_cancel()
signal push_picker(data: Array, on_selected: Callable, ui_constructor)
signal push_cinematic(texts: Array[String], config: Dictionary)
signal cinematic_start(texts: Array[String], config: Dictionary)
signal cinematic_finished()
signal imaginary_changed()
signal request_add_imaginary(tag: String)
signal on_trait_change()
signal on_flag_change()
signal lianju_score_calculated(score: int)

# ── 图像特效信号 ──────────────────────────────────────────
## 请求播放图片粉碎解体特效 (由 ImageEffectManager 监听)
signal request_play_shatter(texture: Texture2D, global_pos: Vector2, duration: float)
## 请求 NarrativeOverlay 追踪一个舞台动画（AnimationObject）
signal request_track_stage_animation(anim: AnimationObject)

## 请求 NarrativeOverlay 执行动画（策略驱动，日后可扩展为不同动画类编排）
## strategy: 策略枚举名（当前支持 "slide_out_and_back"）
## params:  策略参数字典，如 {"duration": 0.5}
signal request_overlay_animation(strategy: String, params: Dictionary)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		user_clicked.emit(null)
