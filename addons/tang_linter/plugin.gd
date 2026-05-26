@tool
extends EditorPlugin

const CONSOLE_SCENE = preload("res://addons/tang_linter/linter_console.tscn")
var console_instance: Control

func _enter_tree():
	# 🤓☝️ 核心动作：实例化你的 CLI 场景，并将其物理插入到编辑器的底部面板！
	console_instance = CONSOLE_SCENE.instantiate()
	add_control_to_bottom_panel(console_instance, "大唐Linter")

func _exit_tree():
	# 🚨 必须优雅释放！防止场景关闭后内存泄漏污染编辑器进程
	if console_instance:
		remove_control_from_bottom_panel(console_instance)
		console_instance.queue_free()