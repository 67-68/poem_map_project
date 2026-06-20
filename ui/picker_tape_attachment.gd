class_name PickerTapeAttachment extends VBoxContainer
## 呈堂物证 — 纸带内嵌选择网格（木牍/令牌），选后定格

signal item_selected(entity: GameEntity)
signal cancelled()

var _data: Array = []
var _on_selected_callback: Callable = Callable()
var _selected: bool = false
var _item_card_scene: PackedScene = preload("res://ui/picker_item_card.tscn")

@onready var grid: GridContainer = $Grid
@onready var header: Label = $Header


func initialize(data: Array, ui_constructor: Callable = Callable()) -> void:
	_data = data

	# 填充网格
	for entity in data:
		var card: PickerItemCard
		if ui_constructor.is_null():
			card = _item_card_scene.instantiate()
			card.initialize(entity if entity is GameEntity else null)
		else:
			card = ui_constructor.call(entity)
			if not card is PickerItemCard:
				Logging.warn("PickerTapeAttachment: ui_constructor 返回的不是 PickerItemCard，跳过")
				continue

		card.clicked.connect(_on_card_clicked.bind(card))
		grid.add_child(card)


func _on_card_clicked(card: PickerItemCard) -> void:
	if _selected:
		return
	_selected = true

	# 选中 Tween: 选中放大 + 金色边框
	var selected_tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	selected_tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.3)

	# 变金边
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.86)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.85, 0.65, 0.13)
	card.add_theme_stylebox_override("panel", style)

	# 其他卡片: 缩小 + 变灰
	for child in grid.get_children():
		if child == card:
			continue
		var other := child as PickerItemCard
		if not other:
			continue

		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(other, "scale", Vector2(0.85, 0.85), 0.25)
		tween.parallel().tween_property(other, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.25)

	# 盖印音效（预留：可替换为真实音效）
	# AudioManager.play_stamp_sound()

	# 获取选中实体
	var selected_entity := card.entity

	# 延迟发射信号（让动画播完）
	await get_tree().create_timer(0.4, false, true).timeout
	item_selected.emit(selected_entity)
