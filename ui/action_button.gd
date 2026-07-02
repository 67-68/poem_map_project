class_name SceneActionPanel extends Button
# 通用行动/决议按钮 — 同时服务 SceneAction 和 Decision

@export var action: Action

## 锁定闪光 Tween 引用（用于清除旧闪光）
var _flash_tween: Tween = null

## 🆕 当前是否处于灰化锁定状态
var _is_locked: bool = false

# ── Sub-action 挂起数据（picker 回调中使用） ────────────
var _pending_sub_action_main_tag: String = ""
var _pending_sub_action_fallback: String = ""
var _pending_sub_action_tags: Array[String] = []
var _pending_sub_action_results: Array = []

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

@onready var title = $Panel/HBoxContainer/VBoxContainer/Title
@onready var outcome = $Panel/HBoxContainer/VBoxContainer/Outcome
@onready var texture = $Panel/HBoxContainer/TextureRect

func _init() -> void:
	_hover_style = StyleBoxFlat.new()
	_hover_style.bg_color = HOVER_BG_COLOR
	_normal_style = StyleBoxEmpty.new()

func initialize(action_: Action = null):
	#breakpoint
	if action_:
		action = action_
		$Panel/HBoxContainer/VBoxContainer/Title.text = action.name
		$Panel/HBoxContainer/VBoxContainer/Outcome.text = action.description
		
		# ── 图标：有数据则显示，无数据则隐藏 ──
		if action.icon:
			$Panel/HBoxContainer/TextureRect.texture = action.icon
			$Panel/HBoxContainer/TextureRect.visible = true
		else:
			$Panel/HBoxContainer/TextureRect.visible = false
	else:
		Logging.err('there\'s no action input in the init of scene action panel!!!')
		return
	
	# ── 点击：执行 action ──
	pressed.connect(_on_button_pressed)
	
	# ── 锁定闪光（仅 SceneAction 有 main_tag 可匹配）──
	if action is SceneAction:
		EventBus.locked_actions_selected.connect(_on_locked_actions_selected)
	
	# ── Hover 底色绑定 ──
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# ── Hover Popup（Alt 双层揭示）──
	if not action.description.is_empty() or not action.action_results.is_empty() or not action.aciton_requirements.is_empty():
		_register_hover_popup()


## 🆕 设置为灰化锁定态
func set_locked(reason: String) -> void:
	_is_locked = true
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 仍然接收 hover
	tooltip_text = reason if not reason.is_empty() else "暂时无法执行此行动"


## 🆕 解除灰化锁定态，同时从 action.success_hint 设置 tooltip（如有）
func set_unlocked() -> void:
	_is_locked = false
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = action.success_hint if action and not action.success_hint.is_empty() else ""


## 差分更新：只刷 UI 文本/图标，不重建信号 & HoverPopup（已注册的 popup 绑定不变）
func update_action(new_action: Action) -> void:
	action = new_action
	title.text = new_action.name
	outcome.text = new_action.description
	
	# ── 图标：有数据则显示，无数据则隐藏 ──
	if new_action.icon:
		texture.texture = new_action.icon
		texture.visible = true
	else:
		texture.visible = false


## 监听锁定行动信号，匹配当前 action 时触发呼吸闪光
func _on_locked_actions_selected(locked_actions: Array) -> void:
	if not action:
		return
	for locked_action in locked_actions:
		if not locked_action is SceneAction:
			continue
		# 通过 main_tag 前缀匹配（与旧 action_map.gd 一致）
		if locked_action.main_tag == action.main_tag:
			_start_flash()
			return

## 呼吸闪光：亮黄 ↔ 白，循环 4 次，每步 0.4s
func _start_flash() -> void:
	# 清除已有闪光 tween
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_loops(4)
	_flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 0.6), 0.4)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.4)


## 创建 HoverInfoPopup，注入叙事文本 + 向量文本，注册到 HoverPopupManager
func _register_hover_popup() -> void:
	var popup := HoverInfoPopup.new()
	
	# 叙事层（默认可见）
	var narrative := action.description if not action.description.is_empty() else "（无叙述）"
	if _is_locked and not action.dynamic_failed_hint.is_empty():
		narrative = "[color=#cc6666]🔒 %s[/color]\n\n%s" % [action.dynamic_failed_hint, narrative]
	popup.set_narrative_text(narrative)
	
	# 向量层（Alt 按下可见）
	var vector_lines: Array[String] = []
	if not action.aciton_requirements.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 前提 ━━━[/font_size][/color]")
		for req in action.aciton_requirements:
			var desc = req.describe_requirement()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	if not action.action_results.is_empty():
		vector_lines.append("[color=gray][font_size=13]━━━ 结果 ━━━[/font_size][/color]")
		for op in action.action_results:
			var desc = op.describe_preview()
			if not desc.is_empty():
				vector_lines.append("• " + desc)
	popup.set_vector_text("\n".join(vector_lines))
	
	HoverPopupManager.register(self, popup, 0.2, 0.15)


func _on_mouse_entered() -> void:
	if _hover_style and not _hover_style.bg_color == Color.TRANSPARENT:
		self.add_theme_stylebox_override("normal", _hover_style)


func _on_mouse_exited() -> void:
	self.add_theme_stylebox_override("normal", _normal_style)

func _on_button_pressed() -> void:
	# 🆕 前置检查：锁定态 → 弹出 toast，不执行
	if _is_locked:
		var reason := action.dynamic_failed_hint if not action.dynamic_failed_hint.is_empty() else "暂时无法执行此行动"
		EventBus.request_toast.emit(reason, 1)
		Logging.info("SceneActionPanel: 锁定态点击被拦截 action=%s reason=%s" % [action.uuid if action else "NULL", reason])
		return
	
	#breakpoint
	Logging.info("SceneActionPanel: BUTTON_PRESSED name=%s type=%s action_results=%d generator=%s" % [
		action.name if action else "NULL",
		action.get_class() if action else "NULL",
		action.action_results.size() if action and action.action_results else 0,
		"yes" if action and action.generator != null else "no"
	])
	
	# ── Decision 点击计数前置检查：在执行业务逻辑之前判断 ──
	if action is Decision and action.allowed_count >= 0:
		if action._times_clicked >= action.allowed_count:
			# 已达上限，仅刷新 UI，不执行业务逻辑
			Logging.info("SceneActionPanel: Decision '%s' already at limit (clicked=%d, allowed=%d), skip execution" % [
				action.name, action._times_clicked, action.allowed_count
			])
			EventBus.decision_clicked.emit()
			return
		action.record_click()
		Logging.info("SceneActionPanel: Decision '%s' click %d/%d" % [action.name, action._times_clicked, action.allowed_count])
	
	# 🆕 快照：在 begin_action_batch 之前锁定 action 元数据
	# r.operate() 中的 TimeOperator 可能触发 xun 推进 → on_xun_tick → refresh()
	# → update_action() 覆盖 self.action，必须在任何副作用发生前快照
	var _snap_is_scene := action is SceneAction
	var _snap_main_tag := ""
	var _snap_fallback := ""
	var _snap_tags: Array[String] = []
	var _snap_generator = action.generator
	if _snap_is_scene:
		var sa := action as SceneAction
		_snap_main_tag = sa.main_tag
		_snap_fallback = sa.fallback_event_uuid
		_snap_tags = sa.action_tags.duplicate()
	
	# 🆕 possibility 抽奖：generator > possibility（有 generator 时跳过抽奖）
	if _snap_generator == null and action.possibility < 100:
		var roll: int = randi() % 101
		if roll > action.possibility:
			Logging.info("SceneActionPanel: possibility 未中签 (roll=%d, possibility=%d)，执行 failed_result" % [roll, action.possibility])
			action.failed_result.operate()
			return
	
	# 🆕 Sub-action 检测：存在 sub_actions 时弹出 Picker，选择后再执行 operators + scan
	# generator 存在时跳过 sub-action（generator 已预定了事件链）
	if _snap_is_scene and _snap_generator == null and action.sub_actions and not action.sub_actions.is_empty():
		# 挂起元数据，供 _on_sub_action_picked 回调使用
		_pending_sub_action_main_tag = _snap_main_tag
		_pending_sub_action_fallback = _snap_fallback
		_pending_sub_action_tags = _snap_tags.duplicate()
		_pending_sub_action_results = action.action_results.duplicate() if action.action_results else []
		
		var picker_data: Array[GameEntity] = []
		for sub_action in action.sub_actions:
			if not sub_action:
				Logging.warn("SceneActionPanel: sub_actions 包含 null Action，跳过")
				continue
			var entity := GameEntity.new({"uuid": sub_action.uuid, "name": sub_action.name})
			# 每个选项携带父行动的 main_tag（为未来多行动混合 picker 做准备）
			entity.set_meta("parent_main_tag", _snap_main_tag)
			picker_data.append(entity)
		
		Logging.info("SceneActionPanel: sub_actions 检测到 %d 个子行动，弹出 Picker" % picker_data.size())
		EventBus.push_picker.emit(picker_data, _on_sub_action_picked, null)
		return
	
	# 🆕 批量模式：抑制属性变动期间的 reevaluate，全部 results 执行完后统一评估
	ActionManager.begin_action_batch()
	if action.action_results:
		for r in action.action_results: r.operate()
	
	ActionManager.end_action_batch()
	
	# ── Focus session 点击计数 hook ──
	ActionManager.get_focus_controller().notify_click()
	
	# ── Generator 消费（统一入口）──
	var had_generator := _snap_generator != null
	ActionManager.consume_generator(action)
	
	# ── Decision 点击后触发 UI 即时刷新 ──
	if action is Decision and action.allowed_count >= 0:
		EventBus.decision_clicked.emit()
	
	# ⛔ generator 存在时 block 随机事件查找
	# generator 内部通过 PushEventOperator 自行推送事件
	if had_generator:
		return
	
	# 🚀 使用快照数据进行事件扫描（防止 self.action 在 refresh() 中被覆盖）
	if _snap_is_scene:
		for tag in _snap_tags:
			PlayerState.current_action_tags.append(tag)
		var context = {
			'main_tag': _snap_main_tag,
			'fallback_event_uuid': _snap_fallback,
		}
		EventManager.scan_events(0, context)


# ── Sub-action Picker 回调 ──────────────────────────────────

## 玩家从 sub-action picker 中选择一个子行动后回调。
## @param entity: 被选中的子行动 GameEntity（含 uuid=sub_uuid, name=显示名）
func _on_sub_action_picked(entity) -> void:
	var sub_uuid: String = entity.uuid if entity is GameEntity else ""
	if sub_uuid.is_empty():
		Logging.err("_on_sub_action_picked: entity.uuid is empty, aborting")
		return
	
	Logging.info("SceneActionPanel: sub-action '%s' selected (uuid=%s)" % [entity.name if entity else "NULL", sub_uuid])
	
	# 1. 执行父行动的 operators（挂起数据）
	ActionManager.begin_action_batch()
	for r in _pending_sub_action_results:
		r.operate()
	ActionManager.end_action_batch()
	
	ActionManager.get_focus_controller().notify_click()
	
	# 2. 将 sub-action uuid + 父行动 tags 追加到 current_action_tags
	PlayerState.current_action_tags.append(sub_uuid)
	for tag in _pending_sub_action_tags:
		PlayerState.current_action_tags.append(tag)
	
	# 3. AND 模式事件扫描：事件必须同时匹配 sub_uuid 和父 main_tag
	var context = {
		'main_tag': _pending_sub_action_main_tag,
		'fallback_event_uuid': _pending_sub_action_fallback,
		'tag_match_mode': 'all',
	}
	EventManager.scan_events(0, context)
	
	# 清理挂起数据
	_pending_sub_action_main_tag = ""
	_pending_sub_action_fallback = ""
	_pending_sub_action_tags.clear()
	_pending_sub_action_results.clear()
