class_name PickerTapeAttachment extends VBoxContainer
## 呈堂物证 — 纸带内嵌选择网格（木牍/令牌），选后定格
##
## 层级适配：
##   item_selected 信号 — 玩家选择一张卡牌
##   cancelled 信号    — 玩家点击「不回答」LinkButton，视为空选择
##
## 新架构（双栏）：
##   左栏（V）：动态创建 SubActionButton × N（Toggle Mode + ButtonGroup 互斥）
##   右栏（VBoxContainer）：动态创建 NpcActionButton × 1（确认执行按钮）
##
## 地点过滤（通过 RemoteActionFilterManager 统一管理）：
##   - CheckBox「显示异地行动」— 默认隐藏，仅存在异地 item 时显示
##   - 通过 RemoteActionFilterManager + EventBus 双向同步

signal item_selected(entity: GameEntity)
signal cancelled()

var _data: Array = []
var _on_selected_callback: Callable = Callable()
var _selected: bool = false
var _item_card_scene: PackedScene = preload("res://ui/smaller_action_button.tscn")
var _npc_button_scene: PackedScene = preload("res://ui/npc_action_button.tscn")

## 调用方注入的 CheckBox toggle 回调: (toggled_on: bool) → void
var _on_filter_toggled_callback: Callable = Callable()

## 是否存在异地 item（用于决定 CheckBox 可见性）
var _has_remote_item: bool = false

## ButtonGroup — 左栏 SubActionButton 互斥组
var _button_group: ButtonGroup = null

## 右栏 NpcActionButton 引用
var _npc_button: NpcActionButton = null

## 左栏 SubActionButton 列表
var _sub_buttons: Array[SubActionButton] = []

@onready var header: Label = $HBox/Header
@onready var _cancel_btn: LinkButton = $HBox/LinkButton
@onready var _filter_checkbox: CheckBox = $HBox/CheckBox
@onready var _left_panel: VBoxContainer = $"HBoxContainer/V"
@onready var _right_panel: VBoxContainer = $"HBoxContainer/VBoxContainer"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_filter_checkbox.toggled.connect(_on_filter_checkbox_toggled)
	# 监听 RemoteActionFilterManager 的状态变更（ActionPanel CheckBox 切换时同步）
	if not EventBus.remote_actions_filter_changed.is_connected(_on_remote_filter_changed):
		EventBus.remote_actions_filter_changed.connect(_on_remote_filter_changed)
	Logging.info("PickerTapeAttachment._ready: 已连接 LinkButton + CheckBox + remote_actions_filter_changed")


func initialize(data: Array, ui_constructor: Callable = Callable(), on_filter_toggled: Callable = Callable()) -> void:
	_data = data
	_on_filter_toggled_callback = on_filter_toggled

	header.theme_type_variation = &"DefaultText"

	_has_remote_item = false

	# ── 清空旧内容 ──
	for child in _left_panel.get_children():
		child.queue_free()
	for child in _right_panel.get_children():
		child.queue_free()
	_sub_buttons.clear()
	
	# ── 创建 ButtonGroup ──
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = true  # 允许取消选择
	# ButtonGroup 是 Resource，不是 Node，不需要 add_child

	var show_remote := RemoteActionFilterManager.get_show_remote()

	# ── 填充左栏 SubActionButton ──
	for entity in data:
		var card = _item_card_scene.instantiate() as SubActionButton
		card.toggle_mode = true
		card.button_group = _button_group
		card.bind_entity(entity if entity is GameEntity else null)
		card.pressed.connect(func(): _on_sub_button_toggled(card, true))
		
		_left_panel.add_child(card)
		_sub_buttons.append(card)

		# 检查是否存在异地 item
		if entity is GameEntity and entity.get_meta("_place_mismatch", false):
			_has_remote_item = true
			if not show_remote:
				card.visible = false
				Logging.info("PickerTapeAttachment.initialize: 异地 item '%s' 默认隐藏" % entity.name)
			else:
				card.visible = true
				card.modulate = Color(0.6, 0.7, 1.0, 0.9)
				Logging.info("PickerTapeAttachment.initialize: 异地 item '%s' 显示 + 淡蓝色染色" % entity.name)
	
	# ── 填充右栏 NpcActionButton（占位）──
	_npc_button = _npc_button_scene.instantiate()
	_npc_button.execution_completed.connect(func(e: GameEntity):
		Logging.info("PickerTapeAttachment: NpcActionButton 执行完成, 发射 item_selected entity='%s'" % e.name)
		_selected = true
		item_selected.emit(e)
	)
	_right_panel.add_child(_npc_button)
	Logging.info("PickerTapeAttachment.initialize: 右栏 NpcActionButton 占位创建，已连接 execution_completed → item_selected")

	# ── CheckBox 可见性 + 初始勾选态 ──
	_filter_checkbox.visible = _has_remote_item
	if _has_remote_item:
		_filter_checkbox.set_pressed_no_signal(show_remote)
		Logging.info("PickerTapeAttachment.initialize: 检测到异地 sub-action，显示 CheckBox「显示异地行动」pressed=%s" % str(show_remote))
	else:
		Logging.info("PickerTapeAttachment.initialize: 无异地 sub-action，隐藏 CheckBox")


## 左栏 SubActionButton Toggle 回调 — 仅做选中视觉反馈
## 不发射 item_selected — 执行由 NpcActionButton 确认后触发
## 允许自由切换选择，不阻塞 toggle
func _on_sub_button_toggled(btn: SubActionButton, pressed: bool) -> void:
	if not pressed:
		return  # ButtonGroup.allow_unpress 时忽略 unpressed
	
	Logging.info("PickerTapeAttachment._on_sub_button_toggled: entity='%s' uuid='%s'（仅视觉，执行待 NpcActionButton 确认）" % [
		btn.entity.name if btn.entity else "null",
		btn.entity.uuid if btn.entity else "null"
	])
	
	# dismiss 所有 hover
	HoverPopupManager.dismiss_all()
	
	# 选中动画：按钮略微放大
	var selected_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	selected_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.3)
	
	# 其他按钮缩小 + 变灰
	for other in _sub_buttons:
		if other == btn:
			continue
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(other, "scale", Vector2(0.85, 0.85), 0.25)
		tween.parallel().tween_property(other, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.25)
	
	# 盖印音效
	AudioManager.play_sfx_category("stamp_impact")
	# 不发射 item_selected — 等待 NpcActionButton 确认后触发


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

	# 所有左栏卡牌统一变灰 + 缩小
	for btn in _sub_buttons:
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.25)
		tween.parallel().tween_property(btn, "modulate", Color(0.5, 0.5, 0.5, 0.6), 0.25)

	# 拒绝音效
	AudioManager.play_sfx_category("book_flip")

	# 延迟发射信号
	await get_tree().create_timer(0.3, true, true).timeout
	Logging.info("PickerTapeAttachment._on_cancel_pressed: 发射 cancelled 信号")
	cancelled.emit()


## CheckBox「显示异地行动」toggle 回调。
func _on_filter_checkbox_toggled(toggled_on: bool) -> void:
	Logging.info("PickerTapeAttachment._on_filter_checkbox_toggled: toggled_on=%s" % str(toggled_on))

	# 通过 RemoteActionFilterManager 同步全局状态
	RemoteActionFilterManager.set_show_remote(toggled_on)

	_apply_remote_visibility(toggled_on)

	# 调用方注入的回调（若有效）
	if not _on_filter_toggled_callback.is_null():
		_on_filter_toggled_callback.call(toggled_on)
		Logging.info("PickerTapeAttachment._on_filter_checkbox_toggled: 已调用外部 callback")


## 响应 RemoteActionFilterManager 的状态变更
func _on_remote_filter_changed(show: bool) -> void:
	Logging.info("PickerTapeAttachment._on_remote_filter_changed: show=%s" % str(show))
	if _filter_checkbox and _filter_checkbox.button_pressed != show:
		_filter_checkbox.set_pressed_no_signal(show)
		Logging.info("PickerTapeAttachment._on_remote_filter_changed: CheckBox 已同步为 %s" % str(show))
	_apply_remote_visibility(show)


## 应用异地可见性：遍历左栏 SubActionButton，对 _place_mismatch 做显隐 + 淡蓝色染色。
func _apply_remote_visibility(show: bool) -> void:
	for btn in _sub_buttons:
		if not btn.entity:
			continue
		var _is_mismatch: bool = btn.entity.get_meta("_place_mismatch", false)
		if not _is_mismatch:
			continue

		if show:
			btn.visible = true
			btn.modulate = Color(0.6, 0.7, 1.0, 0.9)
			Logging.info("PickerTapeAttachment._apply_remote_visibility: 异地 item '%s' 显示 + 淡蓝色染色" % btn.entity.name)
		else:
			btn.visible = false
			btn.modulate = Color.WHITE
			Logging.info("PickerTapeAttachment._apply_remote_visibility: 异地 item '%s' 隐藏" % btn.entity.name)
