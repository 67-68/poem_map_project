@tool
class_name HoverInfoPopup extends PanelContainer

## Hover 信息浮层 — 包裹 CustomTooltip，支持 Alt 双层揭示
##
## 叙事层（默认）：action.description — NarrativeText type variation（墨青色）
## 向量层（Alt）：describe_preview() + describe_requirement() — DefaultText type variation（深灰）
##
## 使用方式：
##   var popup = HoverInfoPopup.new()
##   popup.set_narrative_text(action.description)
##   popup.set_vector_text(vector_str)
##   HoverPopupManager.register(source_node, popup, 0.5, 0.15)


func _init() -> void:
	# 程序化创建 CustomTooltip 子节点
	# CustomTooltip 是纯 .gd 类（无 class_name），extends PanelContainer
	var ct_script = preload("res://ui/custom_tooltip.gd")
	var ct := PanelContainer.new()
	ct.set_script(ct_script)
	ct.name = "CustomTooltip"
	add_child(ct, false, INTERNAL_MODE_BACK)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 设置叙事层文本（默认可见，墨青色 NarrativeText）
func set_narrative_text(text: String) -> void:
	var ct := _get_ct()
	if ct:
		ct.set_narrative_text(text)


## 设置向量层文本（Alt 按下时可见，深灰色 DefaultText）
func set_vector_text(text: String) -> void:
	var ct := _get_ct()
	if ct:
		ct.set_vector_text(text)


func _get_ct() -> PanelContainer:
	for child in get_children():
		if child.name == "CustomTooltip":
			return child as PanelContainer
	return null
