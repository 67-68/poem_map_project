# main_menu.gd — 主菜单根脚本
# 负责语言切换按钮的逻辑绑定
extends Control

@export var btn_zh: LinkButton
@export var btn_en: LinkButton


func _ready() -> void:
	btn_zh = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/HBoxContainer/LinkButton2
	btn_en = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/HBoxContainer/LinkButton3
	
	Logging.info("MainMenu: _ready — 绑定语言切换按钮")

	if btn_zh:
		if not btn_zh.toggled.is_connected(_on_lang_btn_toggled):
			btn_zh.toggled.connect(_on_lang_btn_toggled.bind("zh"))
		Logging.info("MainMenu: 已连接 btn_zh (中文) toggled 信号")
	else:
		Logging.err("MainMenu: btn_zh 未设置，语言切换按钮失效 💀")

	if btn_en:
		if not btn_en.toggled.is_connected(_on_lang_btn_toggled):
			btn_en.toggled.connect(_on_lang_btn_toggled.bind("en"))
		Logging.info("MainMenu: 已连接 btn_en (English) toggled 信号")
	else:
		Logging.err("MainMenu: btn_en 未设置，语言切换按钮失效 💀")

	# 根据当前 locale 同步按钮 pressed 状态
	_sync_button_state()


func _sync_button_state() -> void:
	var current_locale: String = TranslationServer.get_locale()
	Logging.info("MainMenu: 当前 locale='%s'，同步按钮状态" % current_locale)

	if btn_zh:
		btn_zh.set_pressed_no_signal(current_locale == "zh")
	if btn_en:
		btn_en.set_pressed_no_signal(current_locale == "en")


## LinkButton toggled 回调 — button_pressed=true 时触发语言切换
func _on_lang_btn_toggled(button_pressed: bool, locale: String) -> void:
	if not button_pressed:
		Logging.info("MainMenu: '%s' 按钮被取消选中（由 ButtonGroup 互斥触发），忽略" % locale)
		return

	Logging.info("MainMenu: 语言切换到 '%s'" % locale)
	TranslationServer.set_locale(locale)
	GameSave.data.locale = locale
	Logging.info("MainMenu: locale 已写入 GameSave.data.locale='%s'，即将重载场景刷新 UI" % locale)

	# 重载场景以刷新所有 tr() 文本到新语言
	# 主菜单无运行时状态需要保留，直接重载即可
	get_tree().reload_current_scene()
