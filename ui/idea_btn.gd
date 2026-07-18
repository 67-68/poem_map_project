extends Button
class_name IdeaBtn

## IdeaBtn — 理念选择/展示按钮
##
## 用于 IdeaPage 的左右两栏：
##   - 左栏：已解锁理念（5 槽位）
##   - 右栏：候选理念池（可点击选择）
##
## set_idea() 填充数据后自动更新显示文本。

var idea_uuid: String = ""  # 关联的 Idea uuid，空=空槽位
var _idea: Idea = null
var _locked: bool = false
var _conflict_reason: String = ""


func set_idea(idea: Idea, locked: bool = false, conflict_reason: String = "") -> void:
	_idea = idea
	_locked = locked
	_conflict_reason = conflict_reason

	if not idea:
		idea_uuid = ""
		disabled = true
		_update_display_empty()
		return

	idea_uuid = idea.uuid
	disabled = locked
	_update_display()


func get_idea() -> Idea:
	return _idea


func is_locked() -> bool:
	return _locked


func _update_display() -> void:
	if not _idea:
		_update_display_empty()
		return

	# 标题 Label
	var title_label := get_node_or_null("VBoxContainer/HBoxContainer/Label") as Label
	if title_label:
		var name_text: String = _idea.name if not _idea.name.is_empty() else tr("CODE_IDEA_PAGE_099E3CCA8A")
		title_label.text = name_text

	# 描述 Label
	var desc_label := get_node_or_null("VBoxContainer/HBoxContainer/Label2") as Label
	if desc_label:
		if _idea.description.is_empty():
			desc_label.text = ""
		else:
			desc_label.text = _idea.description

	# 可用性/锁定提示 Label
	var lock_label := get_node_or_null("VBoxContainer/Label2") as Label
	if lock_label:
		if _locked and not _conflict_reason.is_empty():
			lock_label.text = tr("CODE_IDEA_BTN_17A8CAB3B2") + _conflict_reason
			lock_label.show()
		elif _locked:
			lock_label.text = tr("CODE_IDEA_BTN_115FA2A54C")
			lock_label.show()
		elif disabled:
			lock_label.text = tr("CODE_IDEA_BTN_460B3574E4")
			lock_label.show()
		else:
			lock_label.text = _conflict_reason
			lock_label.show()


func _update_display_empty() -> void:
	var title_label := get_node_or_null("VBoxContainer/HBoxContainer/Label") as Label
	if title_label:
		title_label.text = ""

	var desc_label := get_node_or_null("VBoxContainer/HBoxContainer/Label2") as Label
	if desc_label:
		desc_label.text = ""

	var lock_label := get_node_or_null("VBoxContainer/Label2") as Label
	if lock_label:
		lock_label.text = ""
		lock_label.hide()
