class_name TraitDemonstrator
extends PanelContainer

## 🆕 tscn 根节点改为 PanelContainer（内嵌 HBoxContainer），脚本移至根节点。
## @onready 延迟绑定在 add_child 前调用 set_trait 时安全（Node 已存在但未 ready）。

@onready var _inner_box: HBoxContainer = $HBoxContainer
@onready var _stamp_label: Label = $HBoxContainer/YangKe/MarginContainer/Label
@onready var _name_label: Label = $HBoxContainer/TraitNameLabel

## 注入 Trait 数据，驱动印章内文字和名称显示
## display_char 优先级：trait_data.display_char > trait_data.name[0]
## 🆕 Imaginary 分支：印章取 name[0]，颜色按等级区分（L1灰/L2白/L3金）
func set_trait(trait_data: Trait) -> void:
	if not trait_data:
		Logging.err("TraitDemonstrator: set_trait 收到了 null trait_data")
		return

	# 印章文字：优先 display_char，回退取 name 第一个字
	var char_to_show: String = trait_data.name[0] if not trait_data.name.is_empty() else "?"
	if not trait_data.display_char.is_empty():
		char_to_show = trait_data.display_char

	if _stamp_label:
		_stamp_label.text = char_to_show
		
		# 🆕 Imaginary 等级颜色：L1灰 / L2白 / L3金
		if trait_data is Imaginary:
			var imag := trait_data as Imaginary
			match imag.level:
				1: _stamp_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))  # 灰色
				2: _stamp_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))  # 白色
				3: _stamp_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))  # 金色
				_: _stamp_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			Logging.info("TraitDemonstrator: Imaginary 印章 Lv%d 颜色已设置" % imag.level)
		else:
			# 普通 Trait：清除颜色覆盖使用默认
			_stamp_label.remove_theme_color_override("font_color")
	else:
		Logging.err("TraitDemonstrator: _stamp_label 为 null，检查节点路径 '$HBoxContainer/YangKe/MarginContainer/Label'")

	if _name_label:
		_name_label.text = tr(trait_data.name)
	else:
		Logging.err("TraitDemonstrator: _name_label 为 null，检查节点路径 '$HBoxContainer/TraitNameLabel'")

	# ── Hover 注册（SLIDE_FROM_LEFT：从左向右滑入 NarrativeOverlay）──
	_register_trait_hover(trait_data)

	Logging.info("TraitDemonstrator: 展示特质 '%s'，印章字='%s'" % [trait_data.name, char_to_show])

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

## 节点从场景树移除时注销 hover 绑定
func _exit_tree() -> void:
	HoverPopupManager.unregister(self)
	Logging.info("TraitDemonstrator._exit_tree: 已注销 hover 绑定")
