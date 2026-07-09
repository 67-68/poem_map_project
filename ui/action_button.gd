class_name SceneActionPanel extends Button
# 通用行动/决议按钮 — 同时服务 SceneAction 和 Decision

@export var action: Action

## 锁定闪光 Tween 引用（用于清除旧闪光）
var _flash_tween: Tween = null

## 🆕 当前是否处于灰化锁定状态
var _is_locked: bool = false

## 🆕 当前是否处于 deferring 状态（淡蓝或淡红）
var _is_deferring: bool = false

# ── Sub-action 挂起数据（picker 回调中使用） ────────────
var _pending_sub_action_main_tag: String = ""
var _pending_sub_action_fallback: String = ""
var _pending_sub_action_tags: Array[String] = []
var _pending_sub_action_results: Array = []
var _pending_parent_day_consumed: float = 0.0
## 🆕 地点过滤 CheckBox 回调：由 PickerTapeAttachment 在 toggle 时调用
## (toggled_on: bool) → void
var _pending_on_checkbox_toggled: Callable = Callable()

# ── Hover 底色（枯墨暗红，极淡，只有交互时才显形）──
const HOVER_BG_COLOR: Color = Color(0.22, 0.05, 0.02, 0.10)
var _hover_style: StyleBoxFlat
var _normal_style: StyleBoxEmpty

# ── 🆕 Defer 视觉颜色 ──
const DEFERRING_COLOR: Color = Color(0.5, 0.6, 1.0, 0.85)      # 淡蓝 — defer 进行中
const DEFER_FAILING_COLOR: Color = Color(1.0, 0.5, 0.5, 0.85)  # 淡红 — 资源不足

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
	if not action.description.is_empty() or not action.action_results.is_empty() or not action.aciton_requirements.is_empty() or action.get_possibility_int() < 100 or (action.failed_result and not action.failed_result.operators.is_empty()):
		_register_hover_popup()


## 🆕 设置为灰化锁定态
func set_locked(reason: String) -> void:
	_is_locked = true
	_is_deferring = false
	modulate = Color(0.4, 0.4, 0.4, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()


## 🆕 解除灰化锁定态
func set_unlocked() -> void:
	_is_locked = false
	_is_deferring = false
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()


## 🆕 设置为 deferring 状态（淡蓝色 — 进行中，可点击取消）
func set_deferring() -> void:
	_is_deferring = true
	# 视觉优先级：红 > 灰 > 蓝 > 白
	# 如果已经被灰化锁定，不覆盖
	if _is_locked:
		return
	modulate = DEFERRING_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()


## 🆕 设置为 defer 资源不足状态（淡红色 — 点击取消或等待自灭）
func set_defer_failing() -> void:
	_is_deferring = true
	# 红色是最高优先级，即使灰化也能覆盖
	modulate = DEFER_FAILING_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hover_popup()


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


## 创建/重建 hover 数据，注入叙事文本 + 向量文本，注册到 HoverPopupManager（SLIDE_FROM_RIGHT 流）
func _register_hover_popup() -> void:
	if not action:
		Logging.warn("SceneActionPanel._register_hover_popup: action is null, skip")
		return
	
	var hint: Dictionary = ActionHintBuilder.build_action_hint(action, _is_locked)
	
	HoverPopupManager.register(self, {"narrative": hint["narrative"], "vector": hint["vector"]}, 0.4, 0.75, HoverPopupManager.FlowType.SLIDE_FROM_RIGHT)
	Logging.info("SceneActionPanel._register_hover_popup: done for '%s' (SLIDE_FROM_RIGHT)" % action.name)


## 注销旧 popup 并重建（用于 set_locked / set_unlocked 后刷新 hover 内容）
func _refresh_hover_popup() -> void:
	if not action:
		Logging.warn("SceneActionPanel._refresh_hover_popup: action is null, skip")
		return
	HoverPopupManager.unregister(self)
	_register_hover_popup()
	Logging.info("SceneActionPanel._refresh_hover_popup: refreshed for '%s'" % action.name)


func _on_mouse_entered() -> void:
	if _hover_style and not _hover_style.bg_color == Color.TRANSPARENT:
		self.add_theme_stylebox_override("normal", _hover_style)


func _on_mouse_exited() -> void:
	self.add_theme_stylebox_override("normal", _normal_style)

func _on_button_pressed() -> void:
	# 🆕 行动开始时 dismiss 所有 hover
	HoverPopupManager.dismiss_all()

	# 🆕 前置检查：deferring 态 → 取消 defer，不继续执行
	if _is_deferring and action and ActionManager.is_deferring(action.uuid):
		Logging.info("SceneActionPanel: deferring 态点击 → 取消 defer action=%s" % action.uuid)
		ActionManager.cancel_defer(action.uuid)
		EventBus.request_toast.emit("已取消等待", 1)
		return

	# 🆕 前置检查：锁定态 → 弹出 toast，不执行
	if _is_locked:
		var reason := action.dynamic_failed_hint if not action.dynamic_failed_hint.is_empty() else "暂时无法执行此行动"
		EventBus.request_toast.emit(reason, 1)
		Logging.info("SceneActionPanel: 锁定态点击被拦截 action=%s reason=%s" % [action.uuid if action else "NULL", reason])
		return
	
	# 🆕 检查 defer_config：如果配置了 xun_defered，启动 defer 而不执行正常流程
	if action and action.defer_config and not action.defer_config.xun_defered.is_empty():
		Logging.info("SceneActionPanel: 检测到 defer_config.xun_defered='%s'，启动 defer action=%s" % [action.defer_config.xun_defered, action.uuid])
		ActionManager.start_defer(action)
		EventBus.request_toast.emit("开始等待（%s 旬）" % action.defer_config.xun_defered, 1)
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
	var _snap_is_scene := action is SceneAction
	var _snap_main_tag := ""
	var _snap_fallback := ""
	var _snap_tags: Array[String] = []
	var _snap_generator = action.generator
	var _snap_day_consumed: float = action.day_consumed
	if _snap_is_scene:
		var sa := action as SceneAction
		_snap_main_tag = sa.main_tag
		_snap_fallback = sa.fallback_event_uuid
		_snap_tags = sa.action_tags.duplicate()
	
	# 🆕 possibility 抽奖：generator > possibility（有 generator 时跳过抽奖）
	if _snap_generator == null and action.get_possibility_int() < 100:
		var roll: int = randi() % 101
		if roll > action.get_possibility_int():
			Logging.info("SceneActionPanel: possibility 未中签 (roll=%d, possibility=%s=%d)，执行 failed_result" % [roll, action.possibility, action.get_possibility_int()])
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
		_pending_parent_day_consumed = action.day_consumed
		
		var picker_data: Array[GameEntity] = []
		for sub_uuid in action.sub_actions:
			if sub_uuid.is_empty():
				Logging.warn("SceneActionPanel: sub_actions 包含空 UUID，跳过")
				continue
			var sub_action: Action = Database.get_action(sub_uuid) as Action
			if not sub_action:
				Logging.warn("SceneActionPanel: sub_actions 中 UUID '%s' 无法解析为 Action，跳过" % sub_uuid)
				continue
			
			# ═══════════════════════════════════════════════
			# 🆕 Phase 1: HIDE 检查 — 不满足即完全隐藏
			#   TraitRequirement / PoemRequirement / FlagRequirement / NarrativeLockRequirement
			#   + operator 级 viability（ConsumeRandomLeverage / PoemReward）
			# ═══════════════════════════════════════════════
			var _should_hide := false
			
			# 🆕 先查找 archetype（success/failure），用于 viability 检查 + Phase 2 + picker 显示
			#   注意：必须放在 viability 检查之前，因为 baiye_threaten 等子行动的
			#   ConsumeRandomLeverageOperator 仅存在于 archetype DSL 中，不在 .tres 的 action_results 里
			var archetype = Database.get_archetype_by_uuid(sub_action.uuid, "success")
			var success_ops: Array = []
			if archetype:
				success_ops = archetype.operators
			var fail_archetype = Database.get_archetype_by_uuid(sub_action.uuid, "failure")
			var fail_ops: Array = []
			if fail_archetype:
				fail_ops = fail_archetype.operators
			
			if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
				for req in sub_action.aciton_requirements:
					if req is TraitRequirement or req is PoemRequirement or req is FlagRequirement or req is NarrativeLockRequirement:
						if not req.compare(PlayerState):
							Logging.info("SceneActionPanel: sub-action '%s' HIDE — requirement type='%s' not met" % [sub_action.uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown"])
							_should_hide = true
							break
			
			# 🆕 检查三源合并的 operator 级 viability（action_results + archetype success_ops + fail_ops）
			if not _should_hide:
				var _viability_ops: Array = []
				if sub_action.action_results:
					_viability_ops.append_array(sub_action.action_results)
				_viability_ops.append_array(success_ops)
				_viability_ops.append_array(fail_ops)
				Logging.info("SceneActionPanel: sub-action '%s' viability check — %d ops (action_results=%d + success_ops=%d + fail_ops=%d)" % [sub_action.uuid, _viability_ops.size(), sub_action.action_results.size() if sub_action.action_results else 0, success_ops.size(), fail_ops.size()])
				for op in _viability_ops:
					if op is ConsumeRandomLeverageOperator:
						if not ConsumeRandomLeverageOperator.is_viable():
							Logging.info("SceneActionPanel: sub-action '%s' HIDE — ConsumeRandomLeverageOperator.is_viable()=false (archetype op, 当前无任何把柄)" % sub_action.uuid)
							_should_hide = true
							break
					elif op is PoemRewardOperator:
						if not PoemRewardOperator.is_viable():
							Logging.info("SceneActionPanel: sub-action '%s' HIDE — PoemRewardOperator.is_viable()=false (archetype op)" % sub_action.uuid)
							_should_hide = true
							break
			
			if _should_hide:
				Logging.info("SceneActionPanel: sub-action '%s' 完全隐藏，不进入 picker" % sub_action.uuid)
				continue
			
			# ═══════════════════════════════════════════════
			# 🆕 Phase 2: GRAY 检查 — 不满足时灰化（可见但锁定）
			#   PropertyRequirement / EmotionRequirement / PropRangeRequirement / 时间
			#   + 🆕 Archetype 属性消耗自动检测
			# ═══════════════════════════════════════════════
			var _gray_reasons: Array[String] = []
			
			if sub_action.aciton_requirements and not sub_action.aciton_requirements.is_empty():
				for req in sub_action.aciton_requirements:
					if req is PropertyRequirement or req is EmotionRequirement or req is PropRangeRequirement:
						if not req.compare(PlayerState):
							var desc := req.describe_requirement() if req.has_method("describe_requirement") else ""
							var reason := desc if not desc.is_empty() else "属性不满足"
							_gray_reasons.append(reason)
							Logging.info("SceneActionPanel: sub-action '%s' GRAY — requirement type='%s' not met: '%s'" % [sub_action.uuid, req.get_script().resource_path.get_file() if req.get_script() else "unknown", reason])
			
			# 🆕 Archetype 属性消耗自动检查：通过 success archetype 的 PropertyOperator 检测属性是否足够
			var arch_cost_reasons := ActionManager.check_archetype_property_costs(success_ops)
			if not arch_cost_reasons.is_empty():
				for r in arch_cost_reasons:
					_gray_reasons.append(r)
				Logging.info("SceneActionPanel: sub-action '%s' GRAY — archetype cost check: %s" % [sub_action.uuid, str(arch_cost_reasons)])
			
			# 🆕 时间检查：不足时灰化（而非隐藏）
			var sub_cost := ActionManager.get_action_day_cost(sub_action, action.day_consumed)
			if sub_cost > 0:
				var current_time := int(PlayerState.get_stat_val("time"))
				if current_time < sub_cost:
					var cost_detail := ActionManager.format_time_detail(action.day_consumed)
					var time_reason := "时间不足（剩余%d天，需要%s）" % [current_time, cost_detail]
					_gray_reasons.append(time_reason)
					Logging.info("SceneActionPanel: sub-action '%s' GRAY — %s" % [sub_action.uuid, time_reason])
			
			# ═══════════════════════════════════════════════
			# 构建 entity（锁定/正常通用）
			# ═══════════════════════════════════════════════
			var entity := GameEntity.new({"uuid": sub_action.uuid, "name": sub_action.name})
			# 每个选项携带父行动的 main_tag（为未来多行动混合 picker 做准备）
			entity.set_meta("parent_main_tag", _snap_main_tag)
			# 附加 Archetype 中的 operators（用于 picker 显示）
			entity.set_meta("operators", success_ops)
			
			# 🆕 地点校验：sub_action 有 required_place 且不匹配当前 stay_place
			var _place_mismatch := false
			var _req_place: int = sub_action.required_place
			if _req_place >= 0:
				var _cur_place: int = ENUMS.from_place_str(PlayerState.stay_place)
				if _cur_place >= 0 and _req_place != _cur_place:
					_place_mismatch = true
					var _place_name := sub_action.get_required_place_name()
					entity.set_meta("_place_mismatch", true)
					entity.set_meta("_required_place_name", _place_name)
					entity.set_meta("_required_place", _req_place)
					Logging.info("SceneActionPanel: sub-action '%s' PLACE_MISMATCH — requires %s (enum=%d), current=%d" % [sub_action.uuid, _place_name, _req_place, _cur_place])
				elif _cur_place < 0:
					Logging.info("SceneActionPanel: sub-action '%s' has required_place=%d but stay_place 未设置，跳过地点过滤" % [sub_action.uuid, _req_place])
			elif _req_place < 0:
				entity.set_meta("_place_mismatch", false)
			
			# 地点不匹配时不走灰化锁定，让 Picker 过滤/染色处理
			if not _place_mismatch and not _gray_reasons.is_empty():
				var joined_reason := "条件不满足：" + "、".join(_gray_reasons)
				entity.set_meta("_is_locked", true)
				entity.set_meta("_locked_reason", joined_reason)
				Logging.info("SceneActionPanel: sub-action '%s' 标记为灰化锁定, reason='%s'" % [sub_action.uuid, joined_reason])
			
			# 🆕 日志：failure archetype 查找结果（已在上方查找并缓存）
			if fail_archetype:
				Logging.info("SceneActionPanel: failure archetype found for '%s' (%d ops)" % [sub_action.uuid, fail_ops.size()])
			else:
				Logging.info("SceneActionPanel: no failure archetype for '%s'" % sub_action.uuid)

			# 🆕 构建 sub-action 预览文本（概率 + 成功效果 + 失败效果 + 时间行）
			if sub_action:
				var preview := _build_sub_action_preview(sub_action, success_ops, fail_ops, action.day_consumed)
				entity.set_meta("sub_action_preview", preview)
				Logging.info("SceneActionPanel: sub_action_preview built for '%s' (%d chars)" % [sub_action.name, preview.length()])
			else:
				entity.set_meta("sub_action_preview", "")

			picker_data.append(entity)
		
		Logging.info("SceneActionPanel: sub_actions 检测到 %d 个子行动，弹出 Picker" % picker_data.size())
		# 🆕 注入 CheckBox toggle 回调，供 PickerTapeAttachment 调用
		_pending_on_checkbox_toggled = _on_picker_checkbox_toggled
		EventBus.push_picker.emit(picker_data, _on_sub_action_picked, null, _pending_on_checkbox_toggled)
		return
	
	# 🆕 重复行动检测：对比当前 action 的识别 tags 与 last_action_tags
	var _identifying_tags: Array[String] = []
	if _snap_is_scene and not _snap_main_tag.is_empty():
		_identifying_tags.append(_snap_main_tag)
	_identifying_tags.append_array(_snap_tags)
	PlayerState._is_repeated_action = PlayerState.is_action_repeated(_identifying_tags)
	Logging.info("SceneActionPanel: _is_repeated_action=%s for identifying_tags=%s" % [str(PlayerState._is_repeated_action), str(_identifying_tags)])
	
	# 🆕 批量模式：抑制属性变动期间的 reevaluate
	ActionManager.begin_action_batch()
	
	# 执行 action_results 中的非时间 operator
	if action.action_results:
		for r in action.action_results:
			r.operate()
	
	# 🆕 时间消耗：通过 day_consumed + trait 惩罚统一扣除（替代原 sprained_ankle 硬编码）
	if _snap_day_consumed > 0:
		var total_cost := ActionManager.get_action_day_cost(action)
		if total_cost > 0:
			PlayerState.append_stat("_time", -total_cost)
			TimeService.advance_time(total_cost)
			Logging.info("[SceneActionPanel] day_consumed=%f, total_cost=%d, 已扣除并推进日历" % [_snap_day_consumed, total_cost])
	
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
		PlayerState.last_action_tags = _snap_tags.duplicate()
		Logging.info("SceneActionPanel: generator 路径，更新 last_action_tags=%s" % str(PlayerState.last_action_tags))
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
	
	# 🆕 重复行动疲惫：执行完毕后更新 last_action_tags
	PlayerState.last_action_tags = _identifying_tags.duplicate()
	Logging.info("SceneActionPanel: 非 sub-action 路径，更新 last_action_tags=%s" % str(PlayerState.last_action_tags))


# ── Sub-action Picker 回调 ──────────────────────────────────

## 玩家从 sub-action picker 中选择一个子行动后回调。
## @param entity: 被选中的子行动 GameEntity（含 uuid=sub_uuid, name=显示名）
func _on_sub_action_picked(entity) -> void:
	# 🆕 空选择（picker 取消）：清理挂起数据后直接返回，不执行任何业务逻辑
	if entity == null:
		Logging.info("_on_sub_action_picked: entity is null（玩家拒绝回答），清理 pending 数据")
		_pending_sub_action_main_tag = ""
		_pending_sub_action_fallback = ""
		_pending_sub_action_tags.clear()
		_pending_sub_action_results.clear()
		_pending_parent_day_consumed = 0.0
		return
	var sub_uuid: String = entity.uuid if entity is GameEntity else ""
	Logging.info("[DEBUG sub_act] ENTER sub_uuid=%s entity_name=%s" % [sub_uuid, entity.name if entity else "NULL"])
	if sub_uuid.is_empty():
		Logging.err("_on_sub_action_picked: entity.uuid is empty, aborting")
		# 同样清理 pending 数据，防止残留
		_pending_sub_action_main_tag = ""
		_pending_sub_action_fallback = ""
		_pending_sub_action_tags.clear()
		_pending_sub_action_results.clear()
		_pending_parent_day_consumed = 0.0
		return

	# 🆕 异地行动：自动消耗 1 天 + 切换 stay_place
	if entity is GameEntity and entity.get_meta("_place_mismatch", false):
		var _req_place: int = entity.get_meta("_required_place", -1)
		var _place_name: String = entity.get_meta("_required_place_name", "")
		Logging.info("SceneActionPanel: sub-action '%s' 异地行动 — 消耗 1 天前往 %s (enum=%d)" % [sub_uuid, _place_name, _req_place])
		TimeService.advance_time(1)
		PlayerState.stay_place = ENUMS.to_place_str(_req_place as ENUMS.CHANGAN_PLACES)
		Logging.info("SceneActionPanel: stay_place 已更新为 %s (%d)" % [_place_name, _req_place])

	Logging.info("SceneActionPanel: sub-action '%s' selected (uuid=%s)" % [entity.name if entity else "NULL", sub_uuid])

		
	# 🆕 查找子 action，使用其 tags 和 fallback（而非父 action 的）
	var sub_action: Action = Database.get_action(sub_uuid) as Action
	var sub_main_tag: String = ""
	var sub_fallback: String = ""
	var sub_tags: Array[String] = []
	
	if sub_action:
		sub_fallback = sub_action.fallback_event_uuid
		sub_tags = sub_action.action_tags.duplicate()
		
		if sub_action is SceneAction:
			# SceneAction：使用其 _main_tag 作为事件桶 key
			sub_main_tag = (sub_action as SceneAction).main_tag
		else:
			# 普通 Action：无单一 main_tag，传空串走全量桶
			# 所有 action_tags 进 current_action_tags，由 ActionTagFilter AND 模式过滤
			sub_main_tag = ""
		Logging.info("SceneActionPanel: sub-action '%s' tags=%s, fallback='%s', main_tag='%s'" % [sub_uuid, str(sub_tags), sub_fallback, sub_main_tag])
	else:
		Logging.warn("SceneActionPanel: sub-action '%s' not found in Database, falling back to parent data" % sub_uuid)
		sub_main_tag = _pending_sub_action_main_tag
		sub_fallback = _pending_sub_action_fallback
		sub_tags = _pending_sub_action_tags.duplicate()
	
	# 🆕 重复行动检测：使用子 action 的识别 tags 对比 last_action_tags
	var _sub_identifying_tags: Array[String] = []
	if not sub_main_tag.is_empty():
		_sub_identifying_tags.append(sub_main_tag)
	_sub_identifying_tags.append_array(sub_tags)
	PlayerState._is_repeated_action = PlayerState.is_action_repeated(_sub_identifying_tags)
	Logging.info("SceneActionPanel._on_sub_action_picked: _is_repeated_action=%s for sub tags=%s" % [str(PlayerState._is_repeated_action), str(_sub_identifying_tags)])
	
	# 🆕 Sub-action possibility 投骰（与父 action _on_button_pressed 逻辑一致）
	# possibility < 100 时投骰判定成功/失败；possibility = 100 时确定性成功
	var _sub_failed: bool = false
	if sub_action and sub_action.get_possibility_int() < 100:
		var roll: int = randi() % 101
		var threshold: int = sub_action.get_possibility_int()
		if roll > threshold:
			Logging.info("SceneActionPanel: sub-action '%s' possibility FAIL (roll=%d > threshold=%d)" % [sub_action.name, roll, threshold])
			sub_action.failed_result.operate()
			_sub_failed = true
		else:
			Logging.info("SceneActionPanel: sub-action '%s' possibility PASS (roll=%d <= threshold=%d)" % [sub_action.name, roll, threshold])
			if sub_action.action_results and not sub_action.action_results.is_empty():
				for r in sub_action.action_results:
					r.operate()
				Logging.info("SceneActionPanel: sub-action '%s' executed action_results (%d ops)" % [sub_action.name, sub_action.action_results.size()])
	
	ActionManager.begin_action_batch()
	
	# 1. 执行父行动的 operators（挂起数据，不含 TimeOperator）
	for r in _pending_sub_action_results:
		r.operate()
	
	# 2. 🆕 时间消耗：基于 effective_day_consumed + trait 惩罚统一扣除
	var total_cost := ActionManager.get_action_day_cost(sub_action, _pending_parent_day_consumed)
	if total_cost > 0:
		PlayerState.append_stat("_time", -total_cost)
		TimeService.advance_time(total_cost)
		Logging.info("[SceneActionPanel] sub-action '%s' day_consumed=%f, total_cost=%d, 已扣除并推进日历" % [sub_action.name if sub_action else "NULL", ActionManager.effective_day_consumed(sub_action, _pending_parent_day_consumed), total_cost])
	
	ActionManager.end_action_batch()
	
	ActionManager.get_focus_controller().notify_click()
	
	# 3. 将 sub-action uuid + 子 action 的 tags 追加到 current_action_tags
	PlayerState.current_action_tags.append(sub_uuid)
	for tag in sub_tags:
		PlayerState.current_action_tags.append(tag)
	
	# 4. AND 模式事件扫描：使用子 action 的 main_tag 和 fallback
	# 🆕 注意：possibility 失败时 failed_result.operate() 已通过 PushEventOperator 推送事件，
	# 因此需要跳过 scan_events 以避免双重事件推送。
	if not _sub_failed:
		var context = {
			'main_tag': sub_main_tag,
			'fallback_event_uuid': sub_fallback,
			'tag_match_mode': 'all',
		}
		EventManager.scan_events(0, context)
	else:
		Logging.info("SceneActionPanel: sub-action '%s' failed, skipping scan_events (failed_result already pushed event)" % sub_action.name)
	
	# 🆕 重复行动疲惫：子 action 执行完毕后更新 last_action_tags
	PlayerState.last_action_tags = _sub_identifying_tags.duplicate()
	Logging.info("SceneActionPanel._on_sub_action_picked: 更新 last_action_tags=%s" % str(PlayerState.last_action_tags))
	
	# 清理挂起数据
	_pending_sub_action_main_tag = ""
	_pending_sub_action_fallback = ""
	_pending_sub_action_tags.clear()
	_pending_sub_action_results.clear()
	_pending_parent_day_consumed = 0.0

# ── Sub-Action Preview 构建 ─────────────────────────────

## 委托到 ActionHintBuilder.build_sub_action_preview（传递 parent_day_consumed）
func _build_sub_action_preview(sub_action: Action, success_ops: Array = [], fail_ops: Array = [], parent_day_consumed: float = 0.0) -> String:
	return ActionHintBuilder.build_sub_action_preview(sub_action, success_ops, fail_ops, parent_day_consumed)


## 🆕 PickerTapeAttachment CheckBox toggle 回调。
## 遍历 picker 中所有 item，根据 _place_mismatch meta 控制可见性和染色。
## 由 PickerTapeAttachment 在 toggle 时通过 _pending_on_checkbox_toggled 调用。
func _on_picker_checkbox_toggled(toggled_on: bool) -> void:
	Logging.info("SceneActionPanel._on_picker_checkbox_toggled: toggled_on=%s" % str(toggled_on))
	# 从 EventBus 信号无法直接拿到 PickerTapeAttachment 引用，
	# 实际遍历由 PickerTapeAttachment 内部完成，此回调为预留钩子。
	Logging.info("SceneActionPanel._on_picker_checkbox_toggled: 委托给 PickerTapeAttachment 内部过滤逻辑")
