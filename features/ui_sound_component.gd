# UISoundComponent.gd
# 🎯 职责：作为纯挂件节点，监听父节点的 UI 信号并委托 AudioManager 播放音效。
# 使用方式：把此节点作为子节点挂给任何 Button / TextureRect / OptionBtn 等控件即可。
# 组合优于继承，零侵入业务代码。
extends Node

# ── 音效类别（优先于单个 click_sound / hover_sound）──
# 对应 assets/sounds/ 下的子目录名，例如 "click" → 从 click/ 随机播一个
@export var click_category: String = ""
@export var hover_category: String = ""

# ── 单音效（向后兼容）──
@export var click_sound: AudioStream    # 点击/按下音效 (当 click_category 非空时忽略)
@export var hover_sound: AudioStream    # 悬停音效 (同上)
@export var pitch_randomness: float = 0.1  # 音高随机偏移量，0 = 无随机

# ── Jitter 抖动效果 ──
@export var enable_jitter: bool = false      # 点击时是否抖动父节点
@export var jitter_strength: float = 4.0     # 抖动幅度(像素)
@export var jitter_duration: float = 0.12    # 抖动总时长(秒)

# ── 可选覆写信号名 ──
# 默认自动检测，但如果父节点信号名比较特殊，可以手动指定
@export var custom_click_signal: String = ""   # 手动指定点击信号名，空=自动检测
@export var custom_hover_signal: String = ""   # 手动指定悬停信号名，空=自动检测

# 常见 UI 信号名列表（按优先级排列）
const _COMMON_CLICK_SIGNALS: PackedStringArray = ["pressed", "toggled", "item_selected", "confirmed"]
const _COMMON_HOVER_SIGNALS: PackedStringArray = ["mouse_entered", "focus_entered"]

var _jitter_tween: Tween   # 防止多个 jitter 冲突


func _ready() -> void:
	var parent = get_parent()
	if not parent:
		push_warning("UISoundComponent: 没有父节点，无法工作")
		return

	# 连点击音效
	_connect_click_signal(parent)

	# 连悬停音效
	_connect_hover_signal(parent)


# ── 点击音效连接 ──
func _connect_click_signal(parent: Node) -> void:
	# 检查是否有任何音效配置（类别 or 单音效）
	if not _has_click_sound():
		return  # 没配置就不连信号，省资源

	# 1. 优先使用手动指定的信号名
	if not custom_click_signal.is_empty():
		if parent.has_signal(custom_click_signal):
			parent.connect(custom_click_signal, _on_click)
			return
		else:
			push_warning("UISoundComponent: 父节点 [%s] 没有自定义点击信号 [%s]" % [parent.name, custom_click_signal])
			# 降级自动检测

	# 2. 自动检测常见点击信号
	for signal_name in _COMMON_CLICK_SIGNALS:
		if parent.has_signal(signal_name):
			parent.connect(signal_name, _on_click)
			return

	# 3. 一个都没找到 → 警告但不崩溃
	push_warning("UISoundComponent: 父节点 [%s] 没有可识别的点击信号，请手动设置 custom_click_signal" % parent.name)


# ── 悬停音效连接 ──
func _connect_hover_signal(parent: Node) -> void:
	if not _has_hover_sound():
		return

	if not custom_hover_signal.is_empty():
		if parent.has_signal(custom_hover_signal):
			parent.connect(custom_hover_signal, _on_hover)
			return
		else:
			push_warning("UISoundComponent: 父节点 [%s] 没有自定义悬停信号 [%s]" % [parent.name, custom_hover_signal])

	for signal_name in _COMMON_HOVER_SIGNALS:
		if parent.has_signal(signal_name):
			parent.connect(signal_name, _on_hover)
			return


# ── 辅助检查 ──
func _has_click_sound() -> bool:
	return not click_category.is_empty() or click_sound != null

func _has_hover_sound() -> bool:
	return not hover_category.is_empty() or hover_sound != null


# ── 音效播放（委托给全局 AudioManager）──
func _on_click() -> void:
	# 1. 优先走类别模式：随机从类别中选一个
	if not click_category.is_empty():
		AudioManager.play_sfx_category(click_category, pitch_randomness)
	elif click_sound:
		# 2. 向后兼容：单音效
		AudioManager.play_sfx(click_sound, pitch_randomness)
	
	# 3. 抖动反馈
	if enable_jitter:
		_apply_jitter()


func _on_hover() -> void:
	if not hover_category.is_empty():
		AudioManager.play_sfx_category(hover_category, pitch_randomness)
	elif hover_sound:
		AudioManager.play_sfx(hover_sound, pitch_randomness)


# ── Jitter 抖动效果 ──
# 对父 Control 的 position 做 Tween 微偏移序列，模拟"触电式"抖动
func _apply_jitter() -> void:
	var parent = get_parent()
	if not parent or not parent is Control:
		return
	
	# 记录原始位置
	var original_pos: Vector2 = parent.position
	
	# 杀掉旧抖动（防止连点叠加）
	if _jitter_tween and _jitter_tween.is_valid():
		_jitter_tween.kill()
	
	_jitter_tween = parent.create_tween()
	_jitter_tween.set_trans(Tween.TRANS_LINEAR)
	
	# 6 次随机微偏移 + 最后归位
	var steps: int = 6
	var step_duration: float = jitter_duration / (steps + 1.0)
	
	for i in range(steps):
		var offset := Vector2(
			randf_range(-jitter_strength, jitter_strength),
			randf_range(-jitter_strength, jitter_strength)
		)
		_jitter_tween.tween_property(parent, "position", original_pos + offset, step_duration)
	
	# 最后归位
	_jitter_tween.tween_property(parent, "position", original_pos, step_duration)
