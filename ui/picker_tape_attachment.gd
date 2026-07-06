class_name PickerTapeAttachment extends VBoxContainer
## 呈堂物证 — 纸带内嵌选择网格（木牍/令牌），选后定格
##
## 层级适配：
##   item_selected 信号 — 玩家选择一张卡牌
##   cancelled 信号    — 玩家点击「不回答」LinkButton，视为空选择

signal item_selected(entity: GameEntity)
signal cancelled()

var _data: Array = []
var _on_selected_callback: Callable = Callable()
var _selected: bool = false
var _item_card_scene: PackedScene = preload("res://picker_item.tscn")

@onready var grid: GridContainer = $Grid
@onready var header: Label = $HBox/Header
@onready var _cancel_btn: LinkButton = $HBox/LinkButton


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	Logging.info("PickerTapeAttachment._ready: 已连接「不回答」LinkButton")


func initialize(data: Array, ui_constructor: Callable = Callable()) -> void:
	_data = data

	header.theme_type_variation = &"DefaultText"

	# 填充网格
	for entity in data:
		var card: PickerItem
		if ui_constructor.is_null():
			card = _item_card_scene.instantiate()
			card.initialize(entity if entity is GameEntity else null)
		else:
			card = ui_constructor.call(entity)
			if not card is PickerItem:
				Logging.warn("PickerTapeAttachment: ui_constructor 返回的不是 PickerItem，跳过")
				continue

		card.clicked.connect(func(_e): _on_card_clicked(card))
		grid.add_child(card)


func _on_card_clicked(card: PickerItem) -> void:
	if _selected:
		return
	_selected = true

	# 🆕 选择后 dismiss 所有 hover
	HoverPopupManager.dismiss_all()

	# 选中 Tween: 选中放大 + 金色边框
	var selected_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
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
		var other := child as PickerItem
		if not other:
			continue

		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(other, "scale", Vector2(0.85, 0.85), 0.25)
		tween.parallel().tween_property(other, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.25)

	# 盖印音效
	AudioManager.play_sfx_category("stamp_impact")

	# 获取选中实体
	var selected_entity := card.entity

	# 延迟发射信号（让动画播完）
	await get_tree().create_timer(0.4, true, true).timeout
	item_selected.emit(selected_entity)


## 玩家点击「不回答」—— 视为空选择，所有卡牌统一变灰并 emit cancelled
func _on_cancel_pressed() -> void:
	if _selected:
		Logging.info("PickerTapeAttachment._on_cancel_pressed: 已选择，忽略重复点击")
		return
	_selected = true
	Logging.info("PickerTapeAttachment._on_cancel_pressed: 玩家拒绝回答，全部卡牌变灰")

	# dismiss 所有 hover
	HoverPopupManager.dismiss_all()

	# 「不回答」按钮自身变灰
	_cancel_btn.modulate = Color(0.4, 0.4, 0.4, 0.5)

	# 所有卡牌统一变灰 + 缩小
	for child in grid.get_children():
		var card := child as PickerItem
		if not card:
			continue
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "scale", Vector2(0.85, 0.85), 0.25)
		tween.parallel().tween_property(card, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.25)

	# 拒绝音效（轻量纸张音）
	AudioManager.play_sfx_category("book_flip")

	# 延迟发射信号（让动画播完）
	await get_tree().create_timer(0.3, true, true).timeout
	Logging.info("PickerTapeAttachment._on_cancel_pressed: 发射 cancelled 信号")
	cancelled.emit()
