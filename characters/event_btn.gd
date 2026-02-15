class_name EventBtn extends Button

signal option_made() # 外部连接这个; 不要连接pressed
var option: EventOption

func _init(data: EventOption):
	option = data
	if data.disabled:
		tooltip_text = data.disabled_reason
		pressed.connect(disable_btn)
	else:
		pressed.connect(confirmed)

func confirmed():
	option_made.emit()

func disable_btn():
	self.modulate = Color.GRAY
	disabled = true
	Global.request_warning_toast.emit(option.disabled_reason)