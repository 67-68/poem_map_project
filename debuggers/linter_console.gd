@tool
extends VBoxContainer

@onready var output_log: RichTextLabel = $OutputLog
@onready var command_input: LineEdit = $CommandInput

func _ready():
	command_input.text_submitted.connect(_on_command_submitted)
	_log("[color=yellow][b]⚔️ 大唐数值资产控制台已挂载。输入 'help' 查看可用指令。[/b][/color]")

func _on_command_submitted(new_text: String):
	var cmd = new_text.strip_edges().to_lower()
	command_input.clear()
	
	_log("[color=gray]> " + new_text + "[/color]") # 回显命令
	
	match cmd:
		"help":
			_log("[color=cyan]fetch[/color] - 从云端同步原始 CSV 资产")
			_log("[color=cyan]lint[/color]  - 执行数据完整性与永动机漏洞静态扫描")
			_log("[color=cyan]bake[/color]  - 将原始数据分流打包为 O(1) .tres 运行时数据库")
		"clear":
			output_log.clear()
		"fetch":
			_log("[color=green]🚀 开始执行异步链式下载...[/color]")
			# 这里可以无缝调用你之前写好的 DATA_MANIFEST 队列逻辑！
		"lint":
			_log("[color=red][b]😡 [Linter Error] 发现永动机选项！事件 [event_9527] 消耗时间为0却提供奖励！[/b][/color]")
		_:
			_log("[color=magenta]💀 未知指令。输入 'help' 获取救赎。[/color]")

func _log(text: String):
	output_log.append_text(text + "\n")