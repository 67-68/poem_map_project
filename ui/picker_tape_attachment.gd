class_name PickerTapeAttachment extends VBoxContainer
## 呈堂物证 — 纸带内嵌选择网格（木牍/令牌），选后定格
##
## 层级适配：
##   item_selected 信号 — 玩家选择一张卡牌
##   cancelled 信号    — 玩家点击「不回答」LinkButton，视为空选择
##
## 🆕 地点过滤：
##   - CheckBox「显示异地行动」— 默认隐藏，仅存在异地 item 时显示
##   - 调用方通过 initialize() 注入 _on_filter_toggled_callback 处理 CheckBox 逻辑
##   - 异地 item 显示时调制为淡蓝色 (Color(0.6, 0.7, 1.0, 0.9))

signal item_selected(entity: GameEntity)
signal cancelled()

var _data: Array = []
var _on_selected_callback: Callable = Callable()
var _selected: bool = false
var _item_card_scene: PackedScene = preload("res://picker_item.tscn")

## 🆕 调用方注入的 CheckBox toggle 回调: (toggled_on: bool, items: Array[PickerItem]) → void
var _on_filter_toggled_callback: Callable = Callable()

@onready var grid: GridContainer = $Grid
@onready var header: Label = $HBox/Header
@onready var _cancel_btn: LinkButton = $HBox/LinkButton
@onready var _filter_checkbox: CheckBox = $HBox/CheckBox


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_filter_checkbox.toggled.connect(_on_filter_checkbox_toggled)
	Logging.info("PickerTapeAttachment._ready: 已连接「不回答」LinkButton + CheckBox")


func initialize(data: Array, ui_constructor: Callable = Callable(), on_filter_toggled: Callable = Callable()) -> void:
	_data = data
	_on_filter_toggled_callback = on_filter_toggled

	header.theme_type_variation = &"DefaultText"

	var _has_mismatch := false

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
		
		# 🆕 检查是否存在异地 item
		if entity is GameEntity and entity.get_meta("_place_mismatch", false):
			_has_mismatch = true
			card.visible = false
			Logging.info("PickerTapeAttachment.initialize: 异地 item '%s' 默认隐藏" % entity.name)

	# 🆕 有异地 item 时显示 CheckBox，否则隐藏
	_filter_checkbox.visible = _has_mismatch
	if _has_mismatch:
		Logging.info("PickerTapeAttachment.initialize: 检测到异地 sub-action，显示 CheckBox「显示异地行动」")
	else:
		Logging.info("PickerTapeAttachment.initialize: 无异地 sub-action，隐藏 CheckBox")


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


## 🆕 CheckBox「显示异地行动」toggle 回调。
## 内部遍历 grid 子节点，对 _place_mismatch item 做显隐 + 淡蓝色染色。
## 同时调用调用方注入的 _on_filter_toggled_callback（若有效）。
func _on_filter_checkbox_toggled(toggled_on: bool) -> void:
	Logging.info("PickerTapeAttachment._on_filter_checkbox_toggled: toggled_on=%s" % str(toggled_on))
	
	for child in grid.get_children():
		var card := child as PickerItem
		if not card or not card.entity:
			continue
		var _is_mismatch: bool = card.entity.get_meta("_place_mismatch", false)
		if not _is_mismatch:
			continue
		
		if toggled_on:
			card.visible = true
			# 淡蓝色染色：区别于灰化锁定 (0.4) 和正常白色
			card.modulate = Color(0.6, 0.7, 1.0, 0.9)
			Logging.info("PickerTapeAttachment: 异地 item '%s' 显示 + 淡蓝色染色" % card.entity.name)
		else:
			card.visible = false
			card.modulate = Color.WHITE
			Logging.info("PickerTapeAttachment: 异地 item '%s' 隐藏" % card.entity.name)
	
	# 调用方注入的回调（若有效）
	if not _on_filter_toggled_callback.is_null():
		_on_filter_toggled_callback.call(toggled_on)
		Logging.info("PickerTapeAttachment._on_filter_checkbox_toggled: 已调用外部 callback")
