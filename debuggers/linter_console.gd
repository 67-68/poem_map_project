@tool
extends VBoxContainer

@onready var output_log: RichTextLabel = $OutputLog
@onready var command_input: LineEdit = $CommandInput

func _ready():
	command_input.text_submitted.connect(_on_command_submitted)
	_log(tr("CODE_LINTER_CONSOLE_E79CC36346"))

func _on_command_submitted(new_text: String):
	var cmd = new_text.strip_edges().to_lower()
	command_input.clear()
	
	_log("[color=gray]> " + new_text + "[/color]") # 回显命令
	
	match cmd:
		"help":
			_log(tr("CODE_LINTER_CONSOLE_2F8ABC3F69"))
			_log(tr("CODE_LINTER_CONSOLE_78294FDE39"))
			_log(tr("CODE_LINTER_CONSOLE_89A8022B7B"))
		"clear":
			output_log.clear()
		"fetch":
			_log(tr("CODE_LINTER_CONSOLE_BFCDCC4442"))
			# 这里可以无缝调用你之前写好的 DATA_MANIFEST 队列逻辑！
		"lint":
			_log(tr("CODE_LINTER_CONSOLE_FA600D9974"))
		_:
			_log(tr("CODE_LINTER_CONSOLE_03C60BBCBB"))

func _log(text: String):
	output_log.append_text(text + "\n")
