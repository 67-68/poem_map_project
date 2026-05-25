class_name  EventBtn extends Button

signal option_made(data: ChoiceResult) # 外部连接这个; 不要连接pressed
var option: BaseOption
var click_count := 0

func _init(data: BaseOption):
	data.init()
	option = data
	text = data.description if 'description' in data else "选项"
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable text wrapping
	custom_minimum_size = Vector2(800, 0)  # Set minimum width to match scene
	if 'is_disabled' in data and data.is_disabled:
		tooltip_text = data.disabled_reason
		pressed.connect(disable_btn)
	else:
		pressed.connect(confirmed)

	if data.requirements:
		var pass_prop = data.requirements.compare(PlayerState)
		if pass_prop == null:
			Logging.err('some property can not be found in state')
			return
		if not pass_prop:
			disabled = true
			text = "[%s]%s" % [data.requirements.failed_hint, text] # failed hint 包括描写和属性要求
			if data.requirements.failed_hint.length() > 10:
				Logging.warn('property requirement of %s length > 15 char, can be ugly' % data.requirements.failed_hint)

func confirmed():
	if not double_check():
		return
	option_made.emit(option.choice_result if 'choice_result' in option else null)

func disable_btn():
	if not double_check():
		return
	self.modulate = Color.GRAY
	disabled = true
	var reason = option.disabled_reason if 'disabled_reason' in option else "选项已禁用"
	EventBus.request_warning_toast.emit(reason)

func double_check() -> bool:
	if 'double_check' not in option or not option.double_check: return true
	click_count += 1
	if not click_count >= 2:
		EventBus.request_warning_toast.emit(option.double_check_reason)
		return false
	else: return true 
	
