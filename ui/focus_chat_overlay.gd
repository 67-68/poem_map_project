# GalgameOverlay.gd
extends Control

@onready var left_portrait = $Background/MarginContainer/VBox/HBox/LeftCharacter
@onready var right_portrait = $Background/MarginContainer/VBox/HBox/RightCharacter
@onready var text_label = $Background/MarginContainer/VBox/HBox2/Panel/VBox/ChatLabel
@onready var name_label = $Background/MarginContainer/VBox/HBox2/Panel/VBox/NameLabel

var _dialogue_sequence: Array = []
var _current_index: int = 0
var choice_created := false
var use_choice := false
var data: FocusedChat
var _current_background: Texture2D  # 追踪当前背景，用于延续逻辑
var _context: Dictionary = {}       # 从触发事件传递过来的 context，用于 EventOption.init()

signal chat_finished(result: ChoiceResult)

func play_dialogue_sequence(dialogues: FocusedChat, context: Dictionary = {}):
	data = dialogues
	_context = context.duplicate(true)
	_dialogue_sequence = dialogues.chats
	_current_background = dialogues.icon  # FocusedChat.icon 作为默认背景
	$Background.texture = _current_background
	_current_index = 0
	$Background/MarginContainer/VBox/HBox/V/Title.text = dialogues.name
	$Background/MarginContainer/VBox/HBox/V/Description.text = dialogues.description

	if data.options.size() > 0:
		use_choice = true

	_show_current_line()
	find_texture()

func find_texture():
	if not $Background/MarginContainer/VBox/HBox/LeftCharacter.texture:
		for dia in _dialogue_sequence:
			if dia.texture and dia.chat_position == FocusedChatLine.ChatPosition.LEFT:
				$Background/MarginContainer/VBox/HBox/LeftCharacter.texture = dia.texture
				break
	if not $Background/MarginContainer/VBox/HBox/RightCharacter.texture:
		for dia in _dialogue_sequence:
			if dia.texture and dia.chat_position == FocusedChatLine.ChatPosition.RIGHT:
				$Background/MarginContainer/VBox/HBox/RightCharacter.texture = dia.texture
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
		# ⚠️ 防弹装甲 1：如果选项已经弹出来了，不要吞事件——让按钮自己收点击
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
			# 🔒 对每个 option 执行 init(context)，确保：
			#   - EventOption: custom_context_params 合并、{@key} 模板插值、requirement/choice_result 初始化
			#   - BaseOption: 无操作（空实现）
			for opt in data.options:
				opt.init(_context)
			
			# 展现选项，并立刻打断渲染逻辑！
			$Background/MarginContainer/VBox/OptionBtns.visible = true
			# 把 try_end_dialogue 作为 Callable 传给按钮，让按钮被点时调用它
			$Background/MarginContainer/VBox/OptionBtns.apply_btns(data.options, try_end_dialogue)
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

	# background 延续逻辑：当前句有背景图才切换，否则沿用上一张
	if line.background:
		_current_background = line.background
		$Background.texture = _current_background

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

	# 3. 执行当前行的 operators（动画、属性修改等）
	# 注意：operator 内的动画使用 TWEEN_PAUSE_PROCESS，与翻页并发播放
	line.execute_operators(_context)

# 专属善后部 (只由按钮点击，或无选项结束时调用)
# NarrativeOverlay 已连接 chat_finished 信号，负责 pop 栈 + 恢复世界
func try_end_dialogue(choice_result: ChoiceResult = null):
	chat_finished.emit(choice_result) # 通知 NarrativeOverlay 对话结束
	queue_free()
