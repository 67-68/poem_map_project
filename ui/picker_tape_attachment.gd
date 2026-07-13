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

## 右栏覆盖按钮列表（每次 toggle 重建，NpcActionButton 覆盖模式实例）
var _override_buttons: Array[NpcActionButton] = []

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

	# 🆕 默认选中第一个左栏 SubActionButton
	if not _sub_buttons.is_empty():
		var first_btn = _sub_buttons[0]
		first_btn.set_pressed_no_signal(true)
		# 触发手动选中——模拟 toggle 回调但跳过动画
		_on_sub_button_toggled(first_btn, true, true)
		Logging.info("PickerTapeAttachment.initialize: 默认选中第一个 sub-action '%s'" % first_btn.entity.name if first_btn.entity else "null")


## 左栏 SubActionButton Toggle 回调 — 选中更新 + 重建右栏 override 按钮
## 不发射 item_selected — 执行由 NpcActionButton 确认后触发
## 允许自由切换选择，不阻塞 toggle
## @param skip_animation: 初始默认选中时跳过动画
func _on_sub_button_toggled(btn: SubActionButton, pressed: bool, skip_animation: bool = false) -> void:
	if not pressed:
		return  # ButtonGroup.allow_unpress 时忽略 unpressed
	
	Logging.info("PickerTapeAttachment._on_sub_button_toggled: entity='%s' uuid='%s'" % [
		btn.entity.name if btn.entity else "null",
		btn.entity.uuid if btn.entity else "null"
	])
	
	# dismiss 所有 hover
	HoverPopupManager.dismiss_all()
	
	# 默认选中（skip_animation=true）时 pressed 信号未触发，手动写入 VolatileState
	if skip_animation and btn.entity:
		VolatileState.action_state.selected_sub_action_uuid = btn.entity.uuid
		VolatileState.action_state.selected_entity_place_mismatch = btn.entity.get_meta("_place_mismatch", false)
		VolatileState.action_state.selected_entity_required_place = btn.entity.get_meta("_required_place", "")
		VolatileState.action_state.selected_entity_required_place_name = btn.entity.get_meta("_required_place_name", "")
	
	# 其他按钮统一变灰
	for other in _sub_buttons:
		if other == btn:
			other.modulate = Color.WHITE
		else:
			other.modulate = Color(0.5, 0.5, 0.5, 0.6)
	
	if not skip_animation:
		# 盖印音效
		AudioManager.play_sfx_category("stamp_impact")
	
	# 🆕 更新默认按钮：标题 + SIMPLE profile 四模块
	if btn.entity and _npc_button and is_instance_valid(_npc_button):
		_npc_button.set_action_data(btn.entity.name if btn.entity else "", btn.entity.uuid if btn.entity else "")
	
	# 🆕 重建右栏 override 按钮（基于当前选中的 sub-action）
	_rebuild_right_panel_override_buttons(btn.entity.uuid if btn.entity else "")
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


# ════════════════════════════════════════════════════════════════════
# 🆕 Override Action — 右栏覆盖按钮系统
# ════════════════════════════════════════════════════════════════════

## 查找 override_action 字段指向 selected_uuid 的所有 Action
func _find_override_actions(selected_uuid: String) -> Array[Action]:
	var result: Array[Action] = []
	if selected_uuid.is_empty():
		Logging.info("PickerTapeAttachment._find_override_actions: selected_uuid 为空，跳过")
		return result

	var all_actions: Dictionary = Database.get_actions_all()
	for action_id in all_actions:
		var action: Action = Database.get_action(action_id) as Action
		if action == null:
			continue
		if action.override_action.is_empty():
			continue
		if action.override_action == selected_uuid:
			result.append(action)
			Logging.info("PickerTapeAttachment._find_override_actions: action '%s' override → '%s'" % [action.uuid, selected_uuid])

	Logging.info("PickerTapeAttachment._find_override_actions: selected_uuid='%s' → 找到 %d 个覆盖行动" % [selected_uuid, result.size()])
	return result


## 匹配当前地点下符合条件的 NPC
## 条件：preferred_places 含 stay_place + current_day ∈ appear_days + person_state ≠ uncharted
func _match_npcs_in_current_place() -> Array[NPCDocument]:
	var result: Array[NPCDocument] = []
	var stay_place = PlayerState.stay_place
	var current_day = TimeService.current_day
	var all_docs: Dictionary = Database.get_npc_document_all()

	Logging.info("PickerTapeAttachment._match_npcs_in_current_place: stay_place='%s' current_day=%d npc_count=%d" % [stay_place, current_day, all_docs.size()])

	for target_tag in all_docs:
		var doc: NPCDocument = all_docs[target_tag] as NPCDocument
		if doc == null:
			continue

		# ── person_state == uncharted → 不显示 ──
		var state := doc.person_state
		if state.is_empty():
			state = RelationFlagManager.DEFAULT_PERSON_STATE
		if state == "uncharted":
			Logging.info("PickerTapeAttachment._match_npcs_in_current_place: NPC '%s' state=uncharted → 跳过" % doc.name)
			continue

		# ── 地点匹配（空数组 = 任意地点）──
		if not doc.preferred_places.is_empty():
			if not doc.preferred_places.has(stay_place):
				Logging.info("PickerTapeAttachment._match_npcs_in_current_place: NPC '%s' preferred_places=%s 不含 '%s' → 跳过" % [doc.name, str(doc.preferred_places), stay_place])
				continue

		# ── 时间窗口匹配（空数组 = 始终可用）──
		if not doc.appear_days.is_empty():
			if not doc.appear_days.has(current_day):
				Logging.info("PickerTapeAttachment._match_npcs_in_current_place: NPC '%s' appear_days=%s 不含 day=%d → 跳过" % [doc.name, str(doc.appear_days), current_day])
				continue

		result.append(doc)
		Logging.info("PickerTapeAttachment._match_npcs_in_current_place: NPC '%s' 匹配 ✅ (place=%s, day=%d, state=%s)" % [doc.name, stay_place, current_day, state])

	Logging.info("PickerTapeAttachment._match_npcs_in_current_place: 共匹配 %d 个 NPC" % result.size())
	return result


## 重建右栏 override 按钮。
## 在 selected_uuid 变化时调用：清空旧 override 按钮 → 查找覆盖行动 → 匹配 NPC → 逐对创建 OverrideActionButton。
## NpcActionButton 始终保留在右栏底部不动。
func _rebuild_right_panel_override_buttons(selected_uuid: String) -> void:
	Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: selected_uuid='%s'" % selected_uuid)

	# ── 1. 清空旧的 override 按钮 ──
	for btn in _override_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_override_buttons.clear()

	if selected_uuid.is_empty():
		Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: selected_uuid 为空，跳过 override 创建")
		return

	# ── 2. 查找覆盖行动 ──
	var override_actions: Array[Action] = _find_override_actions(selected_uuid)
	if override_actions.is_empty():
		Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 无覆盖行动，右栏保留默认 NpcActionButton")
		return

	# ── 3. 匹配当前地点 NPC ──
	var matched_npcs: Array[NPCDocument] = _match_npcs_in_current_place()
	if matched_npcs.is_empty():
		Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 无匹配 NPC，跳过 override 创建")
		return

	# ── 4. 逐对创建覆盖按钮（NpcActionButton 覆盖模式）──
	# NpcActionButton 默认按钮始终在右栏最底部。新创建的覆盖按钮插入到默认按钮之前。
	var npc_button_index: int = _npc_button.get_index() if _npc_button and is_instance_valid(_npc_button) else -1

	for override_action in override_actions:
		for npc_doc in matched_npcs:
			var btn := _npc_button_scene.instantiate() as NpcActionButton
			btn.bind(npc_doc, override_action.uuid)
			btn.execution_completed.connect(func(e: GameEntity):
				Logging.info("PickerTapeAttachment: 覆盖按钮 执行完成, 发射 item_selected entity='%s'" % e.name)
				_selected = true
				item_selected.emit(e)
			)

			if npc_button_index >= 0:
				_right_panel.add_child(btn)
				_right_panel.move_child(btn, npc_button_index)
				npc_button_index += 1
			else:
				_right_panel.add_child(btn)

			_override_buttons.append(btn)
			Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 创建覆盖按钮 — npc='%s' action='%s'" % [npc_doc.name, override_action.name])

	Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 共创建 %d 个覆盖按钮" % _override_buttons.size())
