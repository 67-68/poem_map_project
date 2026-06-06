class_name SimpleToast extends Control

# 引用子节点
@onready var label: RichTextLabel = $Label

var _tween: Tween

# ── 颜色常量 ──
const COLOR_INFO := Color(1.0, 1.0, 1.0, 1.0)       # 普通提示：白色
const COLOR_WARNING := Color(1.0, 0.4, 0.4, 1.0)    # 警告：红色

enum ToastType { INFO = 0, WARNING = 1 }

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	modulate.a = 0.0
	
	# 监听新信号
	EventBus.request_toast.connect(_on_toast)
	# 兼容旧信号 (@deprecated)
	EventBus.request_warning_toast.connect(_on_warning_toast_deprecated)
	EventBus.request_text_popup.connect(_on_text_popup_deprecated)

## 新入口：统一 toast 信号
func _on_toast(content: String, type: int) -> void:
	var is_warning = (type == ToastType.WARNING)
	_play(content, COLOR_WARNING if is_warning else COLOR_INFO)

## @deprecated 旧 warning 信号兼容
func _on_warning_toast_deprecated(text: String) -> void:
	_play(text, COLOR_WARNING)

## @deprecated 旧 text_popup 信号兼容
func _on_text_popup_deprecated(text: String) -> void:
	_play(text, COLOR_INFO)

## 核心播放逻辑
func _play(text: String, color: Color) -> void:
	if _tween: _tween.kill()
	show()
	
	# 设置文本 + 黑色背景
	label.text = "[center]%s[/center]" % text
	label.text = Util.add_colored_bg(Color.BLACK, label.text)
	
	# 重置视觉
	modulate = color
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	
	# 动画：淡入 + 缩放
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4)
	
	# 停留
	_tween.set_parallel(false)
	_tween.tween_interval(2.0)
	
	# 消失
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(hide)
