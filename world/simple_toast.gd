class_name SimpleToast extends Control

# 引用子节点
@onready var label: RichTextLabel = $Label

var _tween: Tween
# 默认的红色警告色 (淡红，带一点透明感的幽灵红)
const WARNING_COLOR = Color(1.0, 0.4, 0.4, 1.0) 

func _ready() -> void:
	# 确保不挡鼠标
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 初始化状态
	hide()
	modulate.a = 0.0
	
	# 连接信号 (假设你有一个专门的信号，或者复用旧的)
	# 如果你想区分“正式诗词”和“警告”，建议在 Global 加一个新信号：
	# signal request_warning_toast(text)
	Global.request_warning_toast.connect(show_warning)

func show_warning(text: String):
	#breakpoint
	# 1. 重置状态
	if _tween: _tween.kill()
	show()
	
	# 2. 设置文本 (支持 BBCode，自动居中)
	# 强制加上 [center] 标签确保文字在框内居中
	label.text = "[center]%s[/center]" % text
	label.text = Util.add_colored_bg(Color.BLACK,label.text)
	
	# 3. 视觉重置
	# 设为红色
	modulate = WARNING_COLOR
	modulate.a = 0.0 # 从透明开始
	
	# 简单的“上浮”动画所需的起始位置
	# 假设我们在布局里已经定好了最终位置，我们只需要在动画开始时把 pivot y 往下压一点
	var target_pos = Vector2(0, 0) # 相对于自身锚点的偏移
	position_offset_y(20) # 往下沉 20 像素作为起点
	
	# 4. 动画序列 (The Animation Sequence)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 动作 A: 淡入
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	# 动作 B: 上浮归位 (利用锚点布局，我们操作 pivot_offset 或者 transform 可能更复杂，
	# 简单的做法是操作 position 的相对偏移，或者直接用 position)
	# 为了简单稳健，我们不动 position，只动 scale 或 modulate，或者用 relative position
	# 这里演示最稳健的 relative 移动：
	
	# 修正：直接操作 position 比较危险，因为 Anchors 会控制它。
	# 更好的做法是操作子节点 Label 的 position，或者使用 position 偏移量。
	# 但既然我们是 Control，我们可以利用 pivot 做一个微小的缩放弹跳
	scale = Vector2(0.9, 0.9)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.4)
	
	# 5. 停留与消失
	_tween.set_parallel(false) # 串行
	_tween.tween_interval(2.0) # 停留 2 秒
	
	# 消失动画
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(hide)

# 辅助函数：如果你用了 Anchor，直接改 position 可能会跟布局冲突
# 这是一个临时的视觉偏移 Hack
func position_offset_y(offset: float):
	# 实际上，对于 Anchor 布局，最好不要在代码里硬改 position
	# 所以我上面改用了 Scale 动画，那样更安全且同样有视觉反馈
	pass
