# main_menu.gd — 主菜单根脚本
# 负责语言切换按钮、鸣谢/反馈页面的逻辑绑定
extends Control

@export var btn_zh: LinkButton
@export var btn_en: LinkButton
@export var thanks_page: PanelContainer
@export var response_page: PanelContainer
@export var thank_to_button: LinkButton
@export var response_button: LinkButton
@export var thanks_close_btn: Button
@export var response_close_btn: Button


func _ready() -> void:
	btn_zh = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/HBoxContainer/LinkButton2
	btn_en = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/HBoxContainer/LinkButton3
	
	thanks_page = $ThanksPage
	response_page = $ResponsePage
	thank_to_button = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/ThankToButton
	response_button = $HBoxContainer/VBoxContainer/PanelContainer3/VBoxContainer/ResponseButton
	thanks_close_btn = $ThanksPage/PanelContainer/Button
	response_close_btn = $ResponsePage/PanelContainer/Button
	
	Logging.info("MainMenu: _ready — 绑定 UI 按钮")

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

	if thank_to_button:
		if not thank_to_button.pressed.is_connected(_on_thank_to_pressed):
			thank_to_button.pressed.connect(_on_thank_to_pressed)
		Logging.info("MainMenu: 已连接 ThankToButton → ThanksPage")
	else:
		Logging.err("MainMenu: ThankToButton 未找到 💀")

	if response_button:
		if not response_button.pressed.is_connected(_on_response_pressed):
			response_button.pressed.connect(_on_response_pressed)
		Logging.info("MainMenu: 已连接 ResponseButton → ResponsePage")
	else:
		Logging.err("MainMenu: ResponseButton 未找到 💀")

	if thanks_close_btn:
		if not thanks_close_btn.pressed.is_connected(_on_thanks_close):
			thanks_close_btn.pressed.connect(_on_thanks_close)
		Logging.info("MainMenu: 已连接 ThanksPage X 关闭按钮")
	else:
		Logging.err("MainMenu: ThanksPage X 按钮未找到 💀")

	if response_close_btn:
		if not response_close_btn.pressed.is_connected(_on_response_close):
			response_close_btn.pressed.connect(_on_response_close)
		Logging.info("MainMenu: 已连接 ResponsePage X 关闭按钮")
	else:
		Logging.err("MainMenu: ResponsePage X 按钮未找到 💀")

	if thanks_page:
		thanks_page.visible = false
		Logging.info("MainMenu: ThanksPage 初始隐藏")
	else:
		Logging.err("MainMenu: thanks_page 为 null 💀")

	if response_page:
		response_page.visible = false
		Logging.info("MainMenu: ResponsePage 初始隐藏")
	else:
		Logging.err("MainMenu: response_page 为 null 💀")

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


## 鸣谢按钮 — 显示/隐藏 ThanksPage
func _on_thank_to_pressed() -> void:
	Logging.info("MainMenu: ThankToButton 被点击")
	if not thanks_page:
		Logging.err("MainMenu: thanks_page 为 null，无法切换 💀")
		return
	thanks_page.visible = not thanks_page.visible
	Logging.info("MainMenu: ThanksPage visible=%s" % thanks_page.visible)


## 反馈按钮 — 显示/隐藏 ResponsePage
func _on_response_pressed() -> void:
	Logging.info("MainMenu: ResponseButton 被点击")
	if not response_page:
		Logging.err("MainMenu: response_page 为 null，无法切换 💀")
		return
	response_page.visible = not response_page.visible
	Logging.info("MainMenu: ResponsePage visible=%s" % response_page.visible)


## ThanksPage X 关闭按钮
func _on_thanks_close() -> void:
	Logging.info("MainMenu: ThanksPage X 关闭按钮被点击")
	if thanks_page:
		thanks_page.visible = false
		Logging.info("MainMenu: ThanksPage 已隐藏")
	else:
		Logging.err("MainMenu: thanks_page 为 null，无法关闭 💀")


## ResponsePage X 关闭按钮
func _on_response_close() -> void:
	Logging.info("MainMenu: ResponsePage X 关闭按钮被点击")
	if response_page:
		response_page.visible = false
		Logging.info("MainMenu: ResponsePage 已隐藏")
	else:
		Logging.err("MainMenu: response_page 为 null，无法关闭 💀")
