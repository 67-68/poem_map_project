class_name ItemPickerTapeAttachment extends VBoxContainer
## 品物选择器 — 简易物品列表选择（选诗/选意象/选特质）
##
## 用于 PoemTypeChooseOperator / ImaginaryLevelRewardOperator / LianjuScoreOperator 等
## 需要玩家从一组 Resource（Poem / Trait / 任意）中选择一项的场景。

signal item_selected(item: Resource)
signal cancelled()

var _data: Array = []
var _on_selected_callback: Callable = Callable()
var _selected: bool = false
var _selected_item: Resource = null

var _item_card_scene: PackedScene = preload("res://ui/smaller_action_button.tscn")

@onready var header: Label = $HBox/Header
@onready var _cancel_btn: LinkButton = $HBox/LinkButton
@onready var _confirm_btn: Button = $ConfirmButton
@onready var _list_panel: VBoxContainer = $"ListPanel"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_confirm_btn.disabled = true
	Logging.info("ItemPickerTapeAttachment._ready: 初始化完成")


func initialize(data: Array) -> void:
	_data = data
	_selected = false
	_selected_item = null
	_confirm_btn.disabled = true
	
	header.text = tr("UI_ITEM_PICKER_TAPE_ATTACHMENT_TEXT_0")
	
	for child in _list_panel.get_children():
		child.queue_free()
	
	for item in data:
		var item_name := _resolve_item_name(item)
		var btn := Button.new()
		btn.text = item_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_item_btn_pressed.bind(item, btn))
		_list_panel.add_child(btn)
		Logging.info("ItemPickerTapeAttachment.initialize: 添加物品 '%s'" % item_name)


func _resolve_item_name(item) -> String:
	if item is Poem:
		return "《%s》" % item.name if not item.name.is_empty() else item.uuid
	if item.has_method("get_name"):
		return item.get_name()
	if item.has_method("get"):
		var n = item.get("name")
		if n:
			return n
	return str(item)


func _on_item_btn_pressed(item: Resource, btn: Button) -> void:
	if _selected:
		return
	_selected_item = item
	_confirm_btn.disabled = false
	for child in _list_panel.get_children():
		if child is Button:
			child.modulate = Color(1, 1, 1, 1) if child == btn else Color(0.5, 0.5, 0.5, 0.6)


func _on_confirm_pressed() -> void:
	if _selected or not _selected_item:
		return
	_selected = true
	Logging.info("ItemPickerTapeAttachment: 确认选择 '%s'" % _resolve_item_name(_selected_item))
	item_selected.emit(_selected_item)


func _on_cancel_pressed() -> void:
	if _selected:
		return
	_selected = true
	_cancel_btn.modulate = Color(0.4, 0.4, 0.4, 0.5)
	_confirm_btn.disabled = true
	for child in _list_panel.get_children():
		if child is Button:
			child.modulate = Color(0.4, 0.4, 0.4, 0.5)
	cancelled.emit()
