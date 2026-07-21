class_name TraitDemonstrator
extends PanelContainer

## V11: Imaginary 到期进度 HSeparator 动态长度
## duration_xun=5 旬，HSeparator 宽度 = (remaining/duration) × 此节点最大宽度
## 通过 _notification(NOTIFICATION_RESIZED) 在每次 resize 时自动刷新

@onready var _inner_box: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var _stamp_label: Label = $VBoxContainer/HBoxContainer/YangKe/MarginContainer/Label
@onready var _name_label: Label = $VBoxContainer/HBoxContainer/TraitNameLabel
@onready var _sep: HSeparator = $VBoxContainer/HSeparator

var _tracked_imaginary: Imaginary = null  ## 当前追踪的意象

## 注入 Trait 数据，驱动印章内文字和名称显示
func set_trait(trait_data: Trait) -> void:
	if not trait_data:
		Logging.err("TraitDemonstrator: set_trait 收到了 null trait_data")
		return

	var char_to_show: String = trait_data.name[0] if not trait_data.name.is_empty() else "?"
	if not trait_data.display_char.is_empty():
		char_to_show = trait_data.display_char

	if _stamp_label:
		_stamp_label.text = char_to_show
		
		if trait_data is Imaginary:
			var imag := trait_data as Imaginary
			match imag.level:
				1: _stamp_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
				2: _stamp_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))
				3: _stamp_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
				_: _stamp_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			Logging.info("TraitDemonstrator: Imaginary 印章 Lv%d 颜色已设置, type=%s" % [imag.level, imag.imaginary_type])

			_tracked_imaginary = imag
			_refresh_imaginary_separator()
			if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
				TimeService.on_xun_tick.connect(_on_xun_tick)
				Logging.info("TraitDemonstrator: 已连接 TimeService.on_xun_tick for '%s'" % imag.name)
		else:
			_stamp_label.remove_theme_color_override("font_color")
			_tracked_imaginary = null
			if _sep:
				_sep.visible = false
	else:
		Logging.err("TraitDemonstrator: _stamp_label 为 null，检查节点路径")

	if _name_label:
		_name_label.text = tr(trait_data.name)
	else:
		Logging.err("TraitDemonstrator: _name_label 为 null，检查节点路径")

	_register_trait_hover(trait_data)

	Logging.info("TraitDemonstrator: 展示特质 '%s'，印章字='%s'" % [trait_data.name, char_to_show])


## 每次 PanelContainer 尺寸变化时自动刷新进度条
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _tracked_imaginary:
			_refresh_imaginary_separator()


func _on_xun_tick() -> void:
	if not _tracked_imaginary:
		return
	_refresh_imaginary_separator()


func _refresh_imaginary_separator() -> void:
	if not _sep or not _tracked_imaginary:
		return

	var dur: int = _tracked_imaginary.duration_xun
	if dur <= 0:
		_sep.visible = false
		return

	var remaining: int = dur - _tracked_imaginary.lasting_xun
	if remaining <= 0:
		_sep.visible = false
		Logging.info("TraitDemonstrator._refresh_imaginary_separator: '%s' 已到期" % _tracked_imaginary.name)
		return

	var full_width: float = size.x
	if full_width <= 0:
		Logging.info("TraitDemonstrator._refresh_imaginary_separator: size.x=%.0f，跳过" % full_width)
		return

	_sep.visible = true
	var ratio: float = float(remaining) / float(dur)
	var sep_width: float = ratio * full_width
	_sep.custom_minimum_size = Vector2(sep_width, 1)
	_sep.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Logging.info("TraitDemonstrator._refresh_imaginary_separator: '%s' remaining=%d/%d ratio=%.2f w=%.0f/%.0f" % [_tracked_imaginary.name, remaining, dur, ratio, sep_width, full_width])

## 兼容未在 Database.traits 注册的软 trait（如 poem_recipe_*）
## trait_key: 原始 key（如 "poem_recipe_tian_cheng"）
## display_name: 展示用名称
func set_trait_fallback(trait_key: String, display_name: String) -> void:
	var char_to_show: String = display_name[0] if not display_name.is_empty() else "?"

	if _stamp_label:
		_stamp_label.text = char_to_show
	else:
		Logging.err("TraitDemonstrator: _stamp_label 为 null（fallback），检查节点路径")
	if _name_label:
		_name_label.text = tr(display_name)
	else:
		Logging.err("TraitDemonstrator: _name_label 为 null（fallback），检查节点路径")

	# ── Hover 注册（fallback：简单文本，无效果详情）──
	_register_trait_hover_fallback(trait_key, display_name)

	Logging.info("TraitDemonstrator: 展示软特质 '%s' → '%s'，印章字='%s'" % [trait_key, display_name, char_to_show])

# ── Hover 注册（复用 HoverPopupManager SLIDE_FROM_LEFT 流）────────────

## 从 Trait 构建 hint 文本，注册到 HoverPopupManager。
## 重复调用 set_trait 时先注销旧绑定再注册新绑定。
func _register_trait_hover(trait_data: Trait) -> void:
	HoverPopupManager.unregister(self)
	var hint: String = ActionHintBuilder.new().build_trait_hint(trait_data)
	if hint.is_empty():
		Logging.info("TraitDemonstrator._register_trait_hover: build_trait_hint 返回空，跳过注册")
		return
	HoverPopupManager.register(self, {"narrative": hint, "vector": ""}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_LEFT)
	Logging.info("TraitDemonstrator._register_trait_hover: 注册成功 for '%s' (%d chars)" % [trait_data.name, hint.length()])

## 软 trait fallback：构建简单文本注册到 HoverPopupManager。
func _register_trait_hover_fallback(trait_key: String, display_name: String) -> void:
	HoverPopupManager.unregister(self)
	var hint: String = tr("CODE_TRAIT_DEMONSTRATOR_4D0041FE1D") % display_name
	HoverPopupManager.register(self, {"narrative": hint, "vector": ""}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_LEFT)
	Logging.info("TraitDemonstrator._register_trait_hover_fallback: 注册成功 for '%s'" % trait_key)

## 节点从场景树移除时注销 hover 绑定 + 断开 xun_tick
func _exit_tree() -> void:
	HoverPopupManager.unregister(self)
	if TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.disconnect(_on_xun_tick)
		Logging.info("TraitDemonstrator._exit_tree: 已断开 TimeService.on_xun_tick")
	Logging.info("TraitDemonstrator._exit_tree: 已注销 hover 绑定")
