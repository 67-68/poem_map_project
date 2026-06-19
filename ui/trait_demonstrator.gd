class_name TraitDemonstrator
extends HBoxContainer

## 阳刻印章内文字（YangKe/MarginContainer/Label）
@onready var _stamp_label: Label = $YangKe/MarginContainer/Label

## 特质名称标签（右侧文字）
@onready var _trait_name_label: Label = $TraitNameLabel


## 注入 Trait 数据，驱动印章内文字和名称显示
## display_char 优先级：trait_data.display_char > trait_data.name[0]
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
	else:
		Logging.err("TraitDemonstrator: _stamp_label (YangKe/MarginContainer/Label) 为 null，检查节点路径")

	if _trait_name_label:
		_trait_name_label.text = trait_data.name
	else:
		Logging.err("TraitDemonstrator: _trait_name_label (TraitNameLabel) 为 null，检查节点路径")

	Logging.info("TraitDemonstrator: 展示特质 '%s'，印章字='%s'" % [trait_data.name, char_to_show])
