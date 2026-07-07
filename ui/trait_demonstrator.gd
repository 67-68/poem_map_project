class_name TraitDemonstrator
extends HBoxContainer


## 注入 Trait 数据，驱动印章内文字和名称显示
## display_char 优先级：trait_data.display_char > trait_data.name[0]
## 注意：不使用 @onready，因为 set_trait 可能在 add_child（_ready）之前调用
func set_trait(trait_data: Trait) -> void:
	if not trait_data:
		Logging.err("TraitDemonstrator: set_trait 收到了 null trait_data")
		return

	# 印章文字：优先 display_char，回退取 name 第一个字
	var char_to_show: String = trait_data.name[0] if not trait_data.name.is_empty() else "?"
	if not trait_data.display_char.is_empty():
		char_to_show = trait_data.display_char

	var stamp_label := $YangKe/MarginContainer/Label as Label
	if stamp_label:
		stamp_label.text = char_to_show
	else:
		Logging.err("TraitDemonstrator: $YangKe/MarginContainer/Label 为 null，检查节点路径")

	var name_label := $TraitNameLabel as Label
	if name_label:
		name_label.text = trait_data.name
	else:
		Logging.err("TraitDemonstrator: $TraitNameLabel 为 null，检查节点路径")

	# ── Hover 注册（SLIDE_FROM_LEFT：从左向右滑入 NarrativeOverlay）──
	_register_trait_hover(trait_data)

	Logging.info("TraitDemonstrator: 展示特质 '%s'，印章字='%s'" % [trait_data.name, char_to_show])

## 兼容未在 Database.traits 注册的软 trait（如 poem_recipe_*）
## trait_key: 原始 key（如 "poem_recipe_tian_cheng"）
## display_name: 展示用名称
func set_trait_fallback(trait_key: String, display_name: String) -> void:
	var char_to_show: String = display_name[0] if not display_name.is_empty() else "?"

	var stamp_label := $YangKe/MarginContainer/Label as Label
	if stamp_label:
		stamp_label.text = char_to_show
	else:
		Logging.err("TraitDemonstrator: $YangKe/MarginContainer/Label 为 null，检查节点路径")

	var name_label := $TraitNameLabel as Label
	if name_label:
		name_label.text = display_name
	else:
		Logging.err("TraitDemonstrator: $TraitNameLabel 为 null，检查节点路径")

	# ── Hover 注册（fallback：简单文本，无效果详情）──
	_register_trait_hover_fallback(trait_key, display_name)

	Logging.info("TraitDemonstrator: 展示软特质 '%s' → '%s'，印章字='%s'" % [trait_key, display_name, char_to_show])

# ── Hover 注册（复用 HoverPopupManager SLIDE_FROM_LEFT 流）────────────

## 从 Trait 构建 hint 文本，注册到 HoverPopupManager。
## 重复调用 set_trait 时先注销旧绑定再注册新绑定。
func _register_trait_hover(trait_data: Trait) -> void:
	HoverPopupManager.unregister(self)
	var hint: String = ActionHintBuilder.build_trait_hint(trait_data)
	if hint.is_empty():
		Logging.info("TraitDemonstrator._register_trait_hover: build_trait_hint 返回空，跳过注册")
		return
	HoverPopupManager.register(self, {"narrative": hint, "vector": ""}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_LEFT)
	Logging.info("TraitDemonstrator._register_trait_hover: 注册成功 for '%s' (%d chars)" % [trait_data.name, hint.length()])

## 软 trait fallback：构建简单文本注册到 HoverPopupManager。
func _register_trait_hover_fallback(trait_key: String, display_name: String) -> void:
	HoverPopupManager.unregister(self)
	var hint: String = "【%s】\n（未注册的软特质，无详细效果数据）" % display_name
	HoverPopupManager.register(self, {"narrative": hint, "vector": ""}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_LEFT)
	Logging.info("TraitDemonstrator._register_trait_hover_fallback: 注册成功 for '%s'" % trait_key)

## 节点从场景树移除时注销 hover 绑定
func _exit_tree() -> void:
	HoverPopupManager.unregister(self)
	Logging.info("TraitDemonstrator._exit_tree: 已注销 hover 绑定")
