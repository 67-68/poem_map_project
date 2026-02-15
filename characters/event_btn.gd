class_name EventBtn extends Button

signal option_made() # 外部连接这个; 不要连接pressed
var option: EventOption
var click_count := 0

func _init(data: EventOption):
	option = data
	text = data.description
	if data.is_disabled:
		tooltip_text = data.disabled_reason
		pressed.connect(disable_btn)
	else:
		pressed.connect(confirmed)

func confirmed():
	if not double_check():
		return
	option_made.emit()

func disable_btn():
	if not double_check():
		return
	self.modulate = Color.GRAY
	disabled = true
	Global.request_warning_toast.emit(option.disabled_reason)

func double_check() -> bool:
	if not option.double_check: return true
	click_count += 1
	if not click_count >= 2:
		Global.request_warning_toast.emit(option.double_check_reason)
		return false
	else: return true
	
