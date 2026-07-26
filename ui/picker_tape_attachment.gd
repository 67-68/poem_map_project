class_name SubActionPickerTapeAttachment extends VBoxContainer
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

## 🆕 普通/特殊过滤 — 当前选中类型
const ACTION_FILTER_NORMAL: String = "normal"
const ACTION_FILTER_SPECIAL: String = "special"

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

## 🆕 当前普通/特殊过滤类型
var _current_action_filter: String = ACTION_FILTER_NORMAL

## PickerTapeAttachment → SubActionPickerTapeAttachment 迁移兼容
## 旧代码通过 class_name "PickerTapeAttachment" 引用的地方已全部替换。

@onready var header: Label = $HBox/Header
@onready var _cancel_btn: LinkButton = $HBox/LinkButton
@onready var _filter_checkbox: CheckBox = $HBox/CheckBox
@onready var _normal_btn: LinkButton = $HBox/LinkButton2
@onready var _special_btn: LinkButton = $HBox/LinkButton3
@onready var _left_panel: VBoxContainer = $"HBoxContainer/V"
@onready var _right_panel: VBoxContainer = $"HBoxContainer/VBoxContainer"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	if _filter_checkbox:
		_filter_checkbox.toggled.connect(_on_filter_checkbox_toggled)
	else:
		Logging.warn("PickerTapeAttachment._ready: _filter_checkbox 为 null，跳过 toggle 连线")
	# 监听 RemoteActionFilterManager 的状态变更（ActionPanel CheckBox 切换时同步）
	if not EventBus.remote_actions_filter_changed.is_connected(_on_remote_filter_changed):
		EventBus.remote_actions_filter_changed.connect(_on_remote_filter_changed)

	# 🆕 普通/特殊 LinkButton toggle 过滤
	if _normal_btn:
		_normal_btn.toggled.connect(_on_action_type_filter_toggled.bind(ACTION_FILTER_NORMAL))
	else:
		Logging.warn("PickerTapeAttachment._ready: _normal_btn 为 null，跳过 toggle 连线")
	if _special_btn:
		_special_btn.toggled.connect(_on_action_type_filter_toggled.bind(ACTION_FILTER_SPECIAL))
	else:
		Logging.warn("PickerTapeAttachment._ready: _special_btn 为 null，跳过 toggle 连线")

	Logging.info("PickerTapeAttachment._ready: 已连接 LinkButton(普通/特殊) + CheckBox + remote_actions_filter_changed")


func initialize(data: Array, ui_constructor: Callable = Callable(), on_filter_toggled: Callable = Callable()) -> void:
	_data = data
	_on_filter_toggled_callback = on_filter_toggled

	header.theme_type_variation = &"DefaultText"

	_has_remote_item = false

	# ── 清空旧内容（防御 null panel）──
	if _left_panel:
		for child in _left_panel.get_children():
			child.queue_free()
	if _right_panel:
		for child in _right_panel.get_children():
			child.queue_free()
	_sub_buttons.clear()
	
	# ── 创建 ButtonGroup ──
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = true  # 允许取消选择
	# ButtonGroup 是 Resource，不是 Node，不需要 add_child

	# ── 填充左栏 SubActionButton ──
	for entity in data:
		var card = _item_card_scene.instantiate() as SubActionButton
		card.toggle_mode = true
		card.button_group = _button_group
		card.bind_entity(entity if entity is GameEntity else null)
		card.pressed.connect(func(): _on_sub_button_toggled(card, true))
		
		if _left_panel:
			_left_panel.add_child(card)
		else:
			Logging.warn("PickerTapeAttachment.initialize: _left_panel 为 null，跳过 add_child")
		_sub_buttons.append(card)

		# 检查是否存在异地 item（仅用于 CheckBox 可见性判定）
		if entity is GameEntity and entity.get_meta("_place_mismatch", false):
			_has_remote_item = true
			Logging.info("PickerTapeAttachment.initialize: 异地 item '%s' 已标记" % entity.name)
	
	# ── 填充右栏 NpcActionButton（占位）──
	_npc_button = _npc_button_scene.instantiate()
	_npc_button.execution_completed.connect(func(e: GameEntity):
		Logging.info("PickerTapeAttachment: NpcActionButton 执行完成, 发射 item_selected entity='%s'" % e.name)
		_selected = true
		item_selected.emit(e)
	)
	if _right_panel:
		_right_panel.add_child(_npc_button)
		Logging.info("PickerTapeAttachment.initialize: 右栏 NpcActionButton 占位创建，已连接 execution_completed → item_selected")
	else:
		Logging.warn("PickerTapeAttachment.initialize: _right_panel 为 null，跳过右栏创建")

	# ── CheckBox 可见性 + 初始勾选态 ──
	var _init_show_remote := RemoteActionFilterManager.get_show_remote()
	if _filter_checkbox:
		_filter_checkbox.visible = _has_remote_item and not TutorialController.is_tutorial_active()
		if _has_remote_item:
			_filter_checkbox.set_pressed_no_signal(_init_show_remote)
			Logging.info("PickerTapeAttachment.initialize: 检测到异地 sub-action，显示 CheckBox pressed=%s" % str(_init_show_remote))
		else:
			Logging.info("PickerTapeAttachment.initialize: 无异地 sub-action，隐藏 CheckBox")
	else:
		Logging.warn("PickerTapeAttachment.initialize: _filter_checkbox 为 null，跳过 CheckBox 初始化")

	# 🆕 默认普通按钮 pressed，应用全量过滤
	if _normal_btn:
		_normal_btn.set_pressed_no_signal(true)
	_current_action_filter = ACTION_FILTER_NORMAL
	_apply_filters()

	# 🆕 默认选中第一个可见的左栏 SubActionButton（而非无条件选第一个）
	var first_visible := _get_first_visible_button()
	if first_visible:
		first_visible.set_pressed_no_signal(true)
		# 触发手动选中——模拟 toggle 回调但跳过动画
		_on_sub_button_toggled(first_visible, true, true)
		Logging.info("PickerTapeAttachment.initialize: 默认选中第一个可见 sub-action '%s'" % (first_visible.entity.name if first_visible.entity else "null"))


## 左栏 SubActionButton Toggle 回调 — 选中更新 + 重建右栏 override 按钮
## 不发射 item_selected — 执行由 NpcActionButton 确认后触发
## 允许自由切换选择，不阻塞 toggle
## @param skip_animation: 初始默认选中时跳过动画
func _on_sub_button_toggled(btn: SubActionButton, pressed: bool, skip_animation: bool = false) -> void:
	if not pressed:
		return  # ButtonGroup.allow_unpress 时忽略 unpressed
	
	# 🐛 修复：锁定态按钮不应被选中或执行。防御 initialize / _auto_select_if_needed 直接调用路径。
	if btn._is_locked:
		Logging.info("PickerTapeAttachment._on_sub_button_toggled: 锁定态按钮 '%s' 被触发 toggle，拒绝选中" % (btn.entity.name if btn.entity else "null"))
		btn.set_pressed_no_signal(false)
		# 🆕 仍然更新右侧 NpcActionButton — 让玩家看到锁定原因，而非空白 toast
		_update_right_panel_for_locked(btn)
		return
	
	var is_remote: bool = btn.entity.get_meta("_place_mismatch", false) if btn.entity else false
	var remote_place: String = btn.entity.get_meta("_required_place", "") if btn.entity else ""
	var remote_place_name: String = btn.entity.get_meta("_required_place_name", "") if btn.entity else ""
	
	Logging.info("PickerTapeAttachment._on_sub_button_toggled: [地点DEBUG] entity='%s' uuid='%s', stay_place='%s', is_remote=%s, remote_place='%s'(%s), skip_animation=%s" % [
		btn.entity.name if btn.entity else "null",
		btn.entity.uuid if btn.entity else "null",
		PlayerState.stay_place,
		str(is_remote), remote_place, remote_place_name, str(skip_animation)
	])
	
	# dismiss 所有 hover
	HoverPopupManager.dismiss_all()
	
	# 默认选中（skip_animation=true）时 pressed 信号未触发，手动写入 VolatileState
	if skip_animation and btn.entity:
		VolatileState.action_state.selected_sub_action_uuid = btn.entity.uuid
		VolatileState.action_state.selected_entity_place_mismatch = is_remote
		VolatileState.action_state.selected_entity_required_place = remote_place
		VolatileState.action_state.selected_entity_required_place_name = remote_place_name
		Logging.info("PickerTapeAttachment._on_sub_button_toggled: [地点DEBUG] skip_animation 写入 VolatileState — place_mismatch=%s required_place='%s'" % [str(is_remote), remote_place])
	
	# 其他按钮统一变灰
	for other in _sub_buttons:
		if other == btn:
			other.modulate = Color.WHITE
		else:
			other.modulate = Color(0.5, 0.5, 0.5, 0.6)
	
	if not skip_animation:
		# 盖印音效
		AudioManager.play_sfx_category("stamp_impact")
	
	# 🆕 更新默认按钮：标题 + description + SIMPLE profile 四模块 + 锁定提示
	if btn.entity and _npc_button and is_instance_valid(_npc_button):
		_npc_button.set_action_data(btn.entity.name if btn.entity else "", btn.entity.uuid if btn.entity else "", btn.entity)
	
	# 🆕 重建右栏 override 按钮（基于当前选中的 sub-action）
	# 异地行动时传入目标地点，让 NPC 匹配基于目标地点而非当前 stay_place
	_rebuild_right_panel_override_buttons(btn.entity.uuid if btn.entity else "", is_remote, remote_place)
	# 不发射 item_selected — 等待 NpcActionButton 确认后触发


## 🆕 锁定态按钮被 toggle 时，更新右侧 NpcActionButton 展示锁因
func _update_right_panel_for_locked(btn: SubActionButton) -> void:
	if btn.entity and _npc_button and is_instance_valid(_npc_button):
		_npc_button.set_action_data_for_locked(btn.entity)
		Logging.info("PickerTapeAttachment._update_right_panel_for_locked: 右侧按钮已更新为锁因展示, entity='%s'" % (btn.entity.name if btn.entity else "null"))


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

	# 🆕 使用统一过滤（普通/特殊 + 异地组合）
	_apply_filters()

	# 调用方注入的回调（若有效）
	if not _on_filter_toggled_callback.is_null():
		_on_filter_toggled_callback.call(toggled_on)
		Logging.info("PickerTapeAttachment._on_filter_checkbox_toggled: 已调用外部 callback")

	# ── 若当前选中按钮被隐藏，自动选中第一个可见按钮 ──
	_auto_select_if_needed()


## 响应 RemoteActionFilterManager 的状态变更
func _on_remote_filter_changed(show: bool) -> void:
	Logging.info("PickerTapeAttachment._on_remote_filter_changed: show=%s" % str(show))
	if _filter_checkbox and is_instance_valid(_filter_checkbox) and _filter_checkbox.button_pressed != show:
		_filter_checkbox.set_pressed_no_signal(show)
		Logging.info("PickerTapeAttachment._on_remote_filter_changed: CheckBox 已同步为 %s" % str(show))
	# 🆕 使用统一过滤（普通/特殊 + 异地组合）
	_apply_filters()
	# ── 若当前选中按钮被隐藏，自动选中第一个可见按钮 ──
	_auto_select_if_needed()


## 应用异地可见性：遍历左栏 SubActionButton，对 _place_mismatch 做显隐 + 淡蓝色染色。
## 🆕 已废弃 — 改用 _apply_filters() 统一处理 type + remote 过滤。
## 保留方法签名以防外部调用，但内部委托给 _apply_filters()
func _apply_remote_visibility(_show: bool = false) -> void:
	_apply_filters()


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


## 匹配指定地点下符合条件的 NPC（用于异地行动预览）
## 条件与 _match_npcs_in_current_place 相同，但地点由调用方指定。
func _match_npcs_in_place(place_key: String) -> Array[NPCDocument]:
	var result: Array[NPCDocument] = []
	var current_day = TimeService.current_day
	var all_docs: Dictionary = Database.get_npc_document_all()

	Logging.info("PickerTapeAttachment._match_npcs_in_place: place='%s' current_day=%d npc_count=%d" % [place_key, current_day, all_docs.size()])

	for target_tag in all_docs:
		var doc: NPCDocument = all_docs[target_tag] as NPCDocument
		if doc == null:
			continue

		# ── person_state == uncharted → 不显示 ──
		var state := doc.person_state
		if state.is_empty():
			state = RelationFlagManager.DEFAULT_PERSON_STATE
		if state == "uncharted":
			Logging.info("PickerTapeAttachment._match_npcs_in_place: NPC '%s' state=uncharted → 跳过" % doc.name)
			continue

		# ── 地点匹配（空数组 = 任意地点）──
		if not doc.preferred_places.is_empty():
			if not doc.preferred_places.has(place_key):
				Logging.info("PickerTapeAttachment._match_npcs_in_place: NPC '%s' preferred_places=%s 不含 '%s' → 跳过" % [doc.name, str(doc.preferred_places), place_key])
				continue

		# ── 时间窗口匹配（空数组 = 始终可用）──
		if not doc.appear_days.is_empty():
			if not doc.appear_days.has(current_day):
				Logging.info("PickerTapeAttachment._match_npcs_in_place: NPC '%s' appear_days=%s 不含 day=%d → 跳过" % [doc.name, str(doc.appear_days), current_day])
				continue

		result.append(doc)
		Logging.info("PickerTapeAttachment._match_npcs_in_place: NPC '%s' 匹配 ✅ (place=%s, day=%d, state=%s)" % [doc.name, place_key, current_day, state])

	Logging.info("PickerTapeAttachment._match_npcs_in_place: 共匹配 %d 个 NPC" % result.size())
	return result


## 重建右栏 override 按钮。
## 在 selected_uuid 变化时调用：清空旧 override 按钮 → 查找覆盖行动 → 匹配 NPC → 逐对创建 OverrideActionButton。
## NpcActionButton 始终保留在右栏底部不动。
## @param target_place_override: 异地行动时传入目标地点 key，让 NPC 匹配基于目标地点而非当前 stay_place
func _rebuild_right_panel_override_buttons(selected_uuid: String, is_remote: bool = false, target_place_override: String = "") -> void:
	Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: selected_uuid='%s' is_remote=%s target_place='%s'" % [selected_uuid, str(is_remote), target_place_override])

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

	# ── 3. 匹配 NPC（异地行动时用目标地点替代当前 stay_place）──
	var matched_npcs: Array[NPCDocument]
	if is_remote and not target_place_override.is_empty():
		matched_npcs = _match_npcs_in_place(target_place_override)
		Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 异地行动，使用目标地点 '%s' 匹配 NPC → %d 个" % [target_place_override, matched_npcs.size()])
	else:
		matched_npcs = _match_npcs_in_current_place()
	if matched_npcs.is_empty():
		Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 无匹配 NPC，跳过 override 创建")
		return

	# ── 4. 逐对创建覆盖按钮（NpcActionButton 覆盖模式）──
	# NpcActionButton 默认按钮始终在右栏最底部。新创建的覆盖按钮插入到默认按钮之前。
	var npc_button_index: int = _npc_button.get_index() if _npc_button and is_instance_valid(_npc_button) else -1

	for override_action in override_actions:
		for npc_doc in matched_npcs:
			var btn := _npc_button_scene.instantiate() as NpcActionButton

			# 先添加到场景树，确保 @onready 变量就绪后再 bind
			if npc_button_index >= 0:
				_right_panel.add_child(btn)
				_right_panel.move_child(btn, npc_button_index)
				npc_button_index += 1
			else:
				_right_panel.add_child(btn)

			# 🆕 add_child 之后 @onready 变量可用，再 bind 填充 label 和 hover
			btn.bind(npc_doc, override_action.uuid)
			btn.execution_completed.connect(func(e: GameEntity):
				Logging.info("PickerTapeAttachment: 覆盖按钮 执行完成, 发射 item_selected entity='%s'" % e.name)
				_selected = true
				item_selected.emit(e)
			)

			_override_buttons.append(btn)
			Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 创建覆盖按钮 — npc='%s' action='%s'" % [npc_doc.name, override_action.name])

	Logging.info("PickerTapeAttachment._rebuild_right_panel_override_buttons: 共创建 %d 个覆盖按钮" % _override_buttons.size())


# ════════════════════════════════════════════════════════════════════
# 🆕 普通/特殊 行动类型过滤
# ════════════════════════════════════════════════════════════════════

## 判断 entity 对应的 sub_action 是否为"特殊"行动。
## 规则：检查 cost archetype 中是否有非 PropertyOperator 的 operator（如 ConsumeRandomLeverage 等）。
## 没有 cost archetype → 普通。
func _is_special_sub_action(entity: GameEntity) -> bool:
	if not entity:
		return false
	var uuid: String = entity.uuid
	if uuid.is_empty():
		return false
	var cost_arch = Database.get_archetype_by_uuid(uuid, "cost")
	if cost_arch == null or cost_arch.operators.is_empty():
		Logging.info("PickerTapeAttachment._is_special_sub_action: '%s' 无 cost archetype → 普通" % uuid)
		return false
	for op in cost_arch.operators:
		if not op is PropertyOperator:
			Logging.info("PickerTapeAttachment._is_special_sub_action: '%s' cost archetype 含非 PropertyOperator (%s) → 特殊" % [uuid, op.get_class() if op else "null"])
			return true
	Logging.info("PickerTapeAttachment._is_special_sub_action: '%s' cost archetype 仅含 PropertyOperator → 普通" % uuid)
	return false


## 🆕 普通/特殊 LinkButton toggle 回调
func _on_action_type_filter_toggled(pressed: bool, filter_type: String) -> void:
	if not pressed:
		return  # ButtonGroup.allow_unpress 时忽略 unpressed
	Logging.info("PickerTapeAttachment._on_action_type_filter_toggled: filter_type=%s" % filter_type)
	_current_action_filter = filter_type
	_apply_filters()
	_auto_select_if_needed()


## 🆕 统一应用所有过滤（type + remote），避免互相覆盖。
## 规则：btn.visible = (type_filter_passes) AND (remote_filter_passes)
func _apply_filters() -> void:
	var show_remote := RemoteActionFilterManager.get_show_remote()
	for btn in _sub_buttons:
		if not btn.entity:
			continue
		# ── 类型过滤（普通/特殊）──
		var is_special: bool = btn.entity.get_meta("_is_special", false)
		var type_passes: bool
		if _current_action_filter == ACTION_FILTER_NORMAL:
			type_passes = not is_special
		else:
			type_passes = is_special

		# ── 异地过滤（仅对 _place_mismatch 按钮生效）──
		var is_mismatch: bool = btn.entity.get_meta("_place_mismatch", false)
		var remote_passes: bool = true
		if is_mismatch:
			remote_passes = show_remote

		btn.visible = type_passes and remote_passes

		# ── 异地染色（仅在 visible 且是异地时应用淡蓝色）──
		if btn.visible and is_mismatch:
			btn.modulate = Color(0.6, 0.7, 1.0, 0.9)
		elif btn.visible:
			btn.modulate = Color.WHITE

		Logging.info("PickerTapeAttachment._apply_filters: sub-action='%s' type_passes=%s remote_passes=%s visible=%s" % [btn.entity.name, str(type_passes), str(remote_passes), str(btn.visible)])

	# 🆕 更新 filter 按钮状态（根据是否有可见项）
	_update_filter_button_states()


## 🆕 更新普通/特殊按钮的 disabled 状态 + title。
## 如果某类型在数据中无任何行动（而非当前 filter 不可见），禁用对应按钮并显示提示。
## 同时考虑异地过滤：如果某个异地行动被 CheckBox 隐藏，它也不计入可见计数。
func _update_filter_button_states() -> void:
	var show_remote := RemoteActionFilterManager.get_show_remote()

	# ── 统计普通/特殊分别在去重后有多少项（基于 _is_special meta，非当前 visible）──
	var normal_total := 0
	var special_total := 0
	for btn in _sub_buttons:
		if not btn.entity:
			continue
		var is_special: bool = btn.entity.get_meta("_is_special", false)
		var is_mismatch: bool = btn.entity.get_meta("_place_mismatch", false)

		# 如果异地且 CheckBox 未勾选 → 不计入（即使切 filter 也看不到它）
		if is_mismatch and not show_remote:
			continue

		if is_special:
			special_total += 1
		else:
			normal_total += 1

	# ── 更新普通按钮 ──
	if _normal_btn and is_instance_valid(_normal_btn):
		if normal_total == 0:
			_normal_btn.disabled = true
			_normal_btn.text = tr("CODE_PICKER_TAPE_ATTACHMENT_E234B1D8D2")
			_normal_btn.modulate = Color(0.4, 0.4, 0.4, 0.5)
		else:
			_normal_btn.disabled = false
			_normal_btn.text = tr("UI_PICKER_TAPE_ATTACHMENT_TEXT_3")
			_normal_btn.modulate = Color.WHITE

	# ── 更新特殊按钮 ──
	if _special_btn and is_instance_valid(_special_btn):
		if special_total == 0:
			_special_btn.disabled = true
			_special_btn.text = tr("CODE_PICKER_TAPE_ATTACHMENT_3951965D54")
			_special_btn.modulate = Color(0.4, 0.4, 0.4, 0.5)
		else:
			_special_btn.disabled = false
			_special_btn.text = tr("UI_PICKER_TAPE_ATTACHMENT_TEXT_4")
			_special_btn.modulate = Color.WHITE

	Logging.info("PickerTapeAttachment._update_filter_button_states: normal_total=%d special_total=%d (show_remote=%s)" % [normal_total, special_total, str(show_remote)])


## 🆕 返回第一个可见且未锁定的 SubActionButton（按 _sub_buttons 顺序）
func _get_first_visible_button() -> SubActionButton:
	for btn in _sub_buttons:
		if btn.visible and not btn._is_locked:
			return btn
	return null


## 🆕 若当前选中按钮被隐藏，自动选中第一个可见按钮并重建右栏。
func _auto_select_if_needed() -> void:
	var currently_selected_uuid: String = VolatileState.action_state.selected_sub_action_uuid
	var selected_visible := false
	for btn in _sub_buttons:
		if btn.entity and btn.entity.uuid == currently_selected_uuid and btn.visible:
			selected_visible = true
			break
	if selected_visible:
		return

	var first_visible := _get_first_visible_button()
	if first_visible:
		first_visible.set_pressed_no_signal(true)
		_on_sub_button_toggled(first_visible, true, false)
		Logging.info("PickerTapeAttachment._auto_select_if_needed: 自动选中第一个可见 sub-action '%s'" % (first_visible.entity.name if first_visible.entity else "null"))
	else:
		Logging.info("PickerTapeAttachment._auto_select_if_needed: 无可见 sub-action")
		# 清空右栏
		if _npc_button and is_instance_valid(_npc_button):
			_npc_button.set_action_data("", "", null)
		for btn in _override_buttons:
			if is_instance_valid(btn):
				btn.queue_free()
		_override_buttons.clear()
