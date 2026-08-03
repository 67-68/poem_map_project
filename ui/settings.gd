extends PanelContainer

## Settings — 系统设置面板
## 挂载于 settings.tscn，负责：
## 1. 音量滑块 ↔ GameSave.data.music_volume_ratio 双向绑定
## 2. 语言切换（LinkButton toggled → TranslationServer.set_locale + GameSave.data.locale）

@onready var _music_slider: HSlider = $VBoxContainer/HSlider
@onready var _music_label: Label = $VBoxContainer/Label3
@onready var _btn_zh: LinkButton = $VBoxContainer/HBoxContainer/LinkButton2
@onready var _btn_en: LinkButton = $VBoxContainer/HBoxContainer/LinkButton3
@onready var _auto_scroll_check: CheckButton = $VBoxContainer/AutoScrollCheckButton


func _ready() -> void:
	Logging.info("Settings: _ready 开始初始化")

	# ── 音量滑块 ──
	if _music_slider:
		# 从存档读取当前音量比例，初始化滑块位置
		# GameSave.data.music_volume_ratio 范围 [0.0, 1.0]，HSlider 范围 [0, 100]
		if GameSave and GameSave.data:
			var ratio: float = GameSave.data.music_volume_ratio
			_music_slider.value = ratio * 100.0
			Logging.info("Settings: 音量滑块初始值 = %.0f (ratio=%.2f)" % [_music_slider.value, ratio])
		else:
			Logging.err("Settings: GameSave 或 GameSave.data 不可用，滑块使用默认值 30")
			_music_slider.value = 30.0

		# 初始化 label 显示当前音量
		_update_music_label(_music_slider.value)

		_music_slider.value_changed.connect(_on_music_volume_changed)
		Logging.info("Settings: 音量滑块 value_changed 信号已连接")
	else:
		Logging.err("Settings: HSlider 引用为空，音量控制不可用")

	# ── 语言切换按钮 ──
	if _btn_zh:
		if not _btn_zh.toggled.is_connected(_on_lang_btn_toggled):
			_btn_zh.toggled.connect(_on_lang_btn_toggled.bind("zh"))
		Logging.info("Settings: 已连接 btn_zh (中文) toggled 信号")
	else:
		Logging.err("Settings: btn_zh 引用为空，语言切换按钮失效 💀")

	if _btn_en:
		if not _btn_en.toggled.is_connected(_on_lang_btn_toggled):
			_btn_en.toggled.connect(_on_lang_btn_toggled.bind("en"))
		Logging.info("Settings: 已连接 btn_en (English) toggled 信号")
	else:
		Logging.err("Settings: btn_en 引用为空，语言切换按钮失效 💀")

	# 根据当前 locale 同步按钮 pressed 状态
	_sync_button_state()

	# ── 自动滚动开关 ──
	if _auto_scroll_check and GameSave and GameSave.data:
		var auto_scroll: bool = GameSave.data.flags.get("auto_scroll_enabled", false)
		_auto_scroll_check.button_pressed = auto_scroll
		Logging.info("Settings: auto_scroll_enabled 初始值 = %s" % auto_scroll)
		if not _auto_scroll_check.toggled.is_connected(_on_auto_scroll_toggled):
			_auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
		Logging.info("Settings: 自动滚动 CheckButton toggled 信号已连接")
	else:
		Logging.err("Settings: _auto_scroll_check 或 GameSave 不可用，自动滚动开关失效 💀")


# ═══════════════════════════════════════════════
# 音量控制
# ═══════════════════════════════════════════════

func _on_music_volume_changed(value: float) -> void:
	if not GameSave or not GameSave.data:
		Logging.err("Settings: GameSave 不可用，无法写入音量")
		return

	var ratio: float = clampf(value / 100.0, 0.0, 1.0)
	GameSave.data.music_volume_ratio = ratio
	Logging.info("Settings: music_volume_ratio 已更新 → %.2f (slider=%.0f)" % [ratio, value])

	# 同步更新音量说明 label
	_update_music_label(value)


## 更新 Label3 显示当前音量百分比，通过 tr("UI_SETTING_MUSIC") 做 i18n
## 翻译 key 格式：UI_SETTING_MUSIC = "音量: %d%%" / "Music: %d%%"
func _update_music_label(slider_value: float) -> void:
	if not _music_label:
		Logging.err("Settings: _music_label 引用为空，无法更新音量文本")
		return

	var pct: int = int(slider_value)
	_music_label.text = tr("UI_SETTING_MUSIC") % pct
	Logging.info("Settings: 音量 label 已更新 → '%s'" % _music_label.text)


# ═══════════════════════════════════════════════
# 语言切换
# ═══════════════════════════════════════════════

func _sync_button_state() -> void:
	var current_locale: String = TranslationServer.get_locale()
	Logging.info("Settings: 当前 locale='%s'，同步按钮状态" % current_locale)

	if _btn_zh:
		_btn_zh.set_pressed_no_signal(current_locale == "zh")
	if _btn_en:
		_btn_en.set_pressed_no_signal(current_locale == "en")


## LinkButton toggled 回调 — button_pressed=true 时触发语言切换
## 注意：settings.tscn 位于游戏内（system_menu 子节点），不执行 reload_current_scene
## （游戏内 reload 会丢失运行时状态）。locale 写入 GameSave 后，下次打开面板 /
## 切曲 / 新事件触发时 tr() 文本自然刷新。
func _on_lang_btn_toggled(button_pressed: bool, locale: String) -> void:
	if not button_pressed:
		Logging.info("Settings: '%s' 按钮被取消选中（由 ButtonGroup 互斥触发），忽略" % locale)
		return

	Logging.info("Settings: 语言切换到 '%s'" % locale)
	TranslationServer.set_locale(locale)
	GameSave.data.locale = locale
	Logging.info("Settings: locale 已写入 GameSave.data.locale='%s'" % locale)


# ═══════════════════════════════════════════════
# 自动滚动开关
# ═══════════════════════════════════════════════

func _on_auto_scroll_toggled(button_pressed: bool) -> void:
	GameSave.data.flags["auto_scroll_enabled"] = button_pressed
	Logging.info("Settings: auto_scroll_enabled = %s" % button_pressed)
