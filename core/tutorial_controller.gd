extends Node
## TutorialController — 青年杜甫泰山引导流程线性状态机
##
## 通过物理可见性（按钮/属性的隐藏/显示）引导玩家逐步学习 UI。
## Phase 1-2: event_confirmed 驱动（叙事阶段）
## Phase 4-7: 行动系统 + 多信号驱动（探索阶段）
##
## 信号矩阵:
##   event_confirmed              → Phase 1→2, 2内部, 2→4, Phase 4-7 阶段推进（_on_event_confirmed 独占）
##   stay_place_changed           → Phase 4 迁移检测
##   request_refresh_action_panel → Phase 4-7 非事件路径状态检查（_on_state_check，白名单变化等）
##   on_xun_tick                  → Phase 5 defer 倒计时
##   poems_created                → Phase 7 创作检测
##
## 行动可见性由 ActionManager.tutorial_whitelist 白名单控制（非 block/unblock）。
## 作为 Autoload 注册，自动检测 tutorial_completed 标志。
## 非 tutorial 模式下静默跳过，不影响正常游戏。

enum Phase {
	INIT,
	PHASE_1_MEET,       # 道士出场 + 鸟语花香音效
	PHASE_2_DIALOGUE,   # 对话 + 面板滑入 + 属性揭示（含 trait+health+50）
	PHASE_4_EXPLORE,    # 自由探索（行动驱动）
	PHASE_5_DEFER,      # override + defer 驱散云雾
	PHASE_6_VISION,     # 往上看 + 最后 Lv3 意象
	PHASE_7_POEM,       # 诗词创作 + 理念解锁
	END
}

# ── Phase 4 子阶段 ──
enum Phase4Step {
	VAST_WORLD,           # tut_vast_world 展示中
	FREE_ROAM,            # 仅交游+驻留可见，道士 not_meet
	MOVED_AWAY,           # 驻留迁移完成 → tut_move_away 展示中
	FOG_FOUND,            # tut_move_away 确认 → 出游(查看)解锁
	CHUYOU_VIEWED,        # 出游查看雾 → 提示回找道士
	BACK_AT_TAOIST,       # tut_return_taoist 展示中
	OVERRIDE_LOCKED,      # override 可见但锁定（关系不够）
	OVERRIDE_READY,       # 共饮后关系升级 → override 解锁
}

# ── Phase 5 子阶段 ──
enum Phase5Step {
	DEFERRING,            # defer 进行中（由 _advance_to_phase_5() 进入）
	DEFER_INTERRUPTED,    # 玩家中断 defer
	DEFER_DONE,           # defer 完成
}

# ── Phase 6 子阶段 ──
enum Phase6Step {
	DEFER_DONE_EVENT,     # tut_defer_done 展示中
	LOOK_UP_READY,        # "往上看"可用
	FINAL_IMAGINARY,      # 最后 Lv3 意象获取
}

# ── Phase 7 子阶段 ──
enum Phase7Step {
	POEM_BTN_VISIBLE,     # 写诗按钮可见
	NO_INSPIRATION,       # tut_no_inspiration 展示中（兴=0）
	DRINK_WINE,           # 独酌喝药酒 +40兴
	POEM_CREATED,         # 诗词创作完成
	POEM_REVIEWED,        # tut_poem_review 展示中
	IDEA_UNLOCKED,        # 理念解锁 → tut_idea_unlink 展示中
	FINAL_REVEAL_DONE,    # tut_final_reveal 展示中
	AWAIT_ENDING,         # tut_final_reveal 确认 → END
}

var _current_phase: Phase = Phase.INIT

# ── 子阶段追踪 ──
var _p4_step: Phase4Step = Phase4Step.VAST_WORLD
var _p5_step: Phase5Step = Phase5Step.DEFERRING
var _p6_step: Phase6Step = Phase6Step.DEFER_DONE_EVENT
var _p7_step: Phase7Step = Phase7Step.POEM_BTN_VISIBLE

# ── Phase 2 对话子阶段（4步：tut_dialogue_3已删除, tut_dialogue_4合并了trait_demo）──
var _dialogue_step: int = 0
const DIALOGUE_EVENTS: Array[String] = [
	"tut_dialogue_1",
	"tut_dialogue_time",
	"tut_dialogue_2",
	"tut_dialogue_4",
]

# ── 标志 ──
var _signals_connected: bool = false
var _poem_created: bool = false
var _inspiration_gained: bool = false
var _defer_started: bool = false
var _defer_completed: bool = false
## 🆕 刚进入 Phase 5 时跳过首次 _on_phase_5_action 的中断检测
## （_set_sub_whitelist → request_refresh_action_panel → _on_state_check → _on_phase_5_action，
##  此时 defer 尚未被 SubActionExecutor 启动；event_confirmed 同理在过渡事件期间不应触发检测）
var _just_entered_phase_5: bool = false
## 🆕 刚推进到 LOOK_UP_READY 时跳过紧随的 event_confirmed（tut_defer_done 的 choice_result
##  后果（如 set_stay_place）会在同帧内再次 emit event_confirmed，误触发「往上看确认」）
var _just_entered_lookup_ready: bool = false

# ── UI 可见性快照（tutorial 开始前记录，结束时还原）──
## 结构：{node_path (String): visible (bool)}
var _visibility_snapshot: Dictionary = {}

# ── 游戏存档快照（tutorial 开始前记录，结束时还原）──
## 结构：GameSaveData.to_dict() 返回的完整 Dictionary
var _game_save_snapshot: Dictionary = {}

# ── 道士 NPCDocument key ──
const TAOIST_NPC_KEY := "tut_taoist"


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 如果 tutorial 已完成，跳过
	if PlayerState.has_flag("tutorial_completed"):
		Logging.info("TutorialController: tutorial_completed 标志已存在，跳过 tutorial")
		_ensure_all_ui_visible()
		return

	# 等待 Main 场景加载后再弹窗
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
		Logging.info("TutorialController: 已连接 node_added，等待 Main 场景加载")
	
	PlayerState.register_virtual_flag("tutorial_completed",'bool')


func _on_node_added(node: Node) -> void:
	if node.name != "Main":
		return
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	Logging.info("TutorialController: Main 场景已加载，弹出教程确认 Modal")
	call_deferred("_show_tutorial_prompt")


# ═══════════════════════════════════════════════════════════
# Tutorial 启动确认 Modal
# ═══════════════════════════════════════════════════════════

func _show_tutorial_prompt() -> void:
	if PlayerState.has_flag("tutorial_completed"):
		return

	# 从 main.tscn 场景树中获取已有的 ConfirmationDialogCustom 实例
	# 路径: Main/UI/ConfirmationDialogCustom
	var dialog := _get_tutorial_dialog()
	if not dialog:
		Logging.err("TutorialController: 找不到 Main/UI/ConfirmationDialogCustom 节点，兜底跳过 tutorial")
		_skip_tutorial()
		return

	# 连接「跳过」按钮（unique_id=112152359）
	var skip_btn := dialog.get_node_or_null("PanelContainer/VBoxContainer/HBoxContainer/LinkButton") as LinkButton
	if skip_btn:
		if not skip_btn.pressed.is_connected(_on_tutorial_skip_pressed):
			skip_btn.pressed.connect(_on_tutorial_skip_pressed)
		Logging.info("TutorialController: 已连接「跳过」LinkButton")
	else:
		Logging.err("TutorialController: 找不到「跳过」LinkButton，兜底跳过 tutorial")
		_skip_tutorial()
		return

	# 连接「开始引导」按钮（unique_id=596627211）
	var start_btn := dialog.get_node_or_null("PanelContainer/VBoxContainer/HBoxContainer/LinkButton2") as LinkButton
	if start_btn:
		if not start_btn.pressed.is_connected(_on_tutorial_start_pressed):
			start_btn.pressed.connect(_on_tutorial_start_pressed)
		Logging.info("TutorialController: 已连接「开始引导」LinkButton")
	else:
		Logging.err("TutorialController: 找不到「开始引导」LinkButton，兜底跳过 tutorial")
		_skip_tutorial()
		return

	dialog.visible = true
	Logging.info("TutorialController: 新手教程确认 Modal 已显示（Main/UI/ConfirmationDialogCustom）")


func _get_tutorial_dialog() -> PanelContainer:
	"""返回 main.tscn 中预置的 ConfirmationDialogCustom 实例"""
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	return root.get_node_or_null("Main/UI/ConfirmationDialogCustom") as PanelContainer


func _on_tutorial_skip_pressed() -> void:
	Logging.info("TutorialController: 「跳过」按钮被点击")
	_hide_tutorial_dialog()
	_skip_tutorial()


func _on_tutorial_start_pressed() -> void:
	Logging.info("TutorialController: 「开始引导」按钮被点击")
	_hide_tutorial_dialog()
	_begin_tutorial()


func _hide_tutorial_dialog() -> void:
	var dialog := _get_tutorial_dialog()
	if dialog:
		dialog.visible = false
		Logging.info("TutorialController: ConfirmationDialogCustom 已隐藏")


func _skip_tutorial() -> void:
	TimeService.jump_to_clean(745.0)
	Logging.info("TutorialController: 跳过新手教程")
	ActionManager.clear_tutorial_whitelist()
	ActionManager.clear_tutorial_sub_whitelist()
	# 还原游戏存档快照（兜底：如果 _begin_tutorial 已执行过）
	if not _game_save_snapshot.is_empty():
		_restore_game_save_snapshot()
		Logging.info("TutorialController: [skip] 游戏存档快照已还原")
	# 🆕 set_flag 必须在快照还原之后，否则会被旧快照覆盖
	PlayerState.set_flag("tutorial_completed", true, 'bool')
	# 🆕 全局黑名单：ban 掉 tutorial 特有的子行动（必须在快照还原之后，否则会被覆盖）
	_ban_tutorial_actions()
	# 记录当前可见性（兜底：如果 _begin_tutorial 从未执行），然后还原
	if _visibility_snapshot.is_empty():
		_record_all_visibility(get_tree().root)
		Logging.info("TutorialController: [skip] 快照为空，重新记录")
	_restore_all_visibility(get_tree().root)
	# 兜底：刷新面板内部状态
	_ensure_all_ui_visible()
	Logging.info("TutorialController: [skip] _ensure_all_ui_visible 已调用（兜底刷新）")
	_clear_all_tut_flags()


func _begin_tutorial() -> void:
	Logging.info("TutorialController: ====== 开始新手教程 ======")

	# 🆕 保存游戏存档快照（tutorial 结束后完整还原）
	_record_game_save_snapshot()
	Logging.info("TutorialController: [init 0/9] 游戏存档快照已记录")

	# 设置每旬 2 天
	TimeService.on_xun_tick.emit()

	EventBus.idea_upgraded.connect(_on_phase_7_event_confirmed)

	# 🆕 设置健康/钱为满值（tutorial 结束后切换回 source_of_truth 值）
	var health_prop = Database.get_property("health")
	var money_prop = Database.get_property("money")
	var health_max: int = health_prop.soft_max if health_prop and health_prop.soft_max > 0 else 100
	var money_max: int = money_prop.soft_max if money_prop and money_prop.soft_max > 0 else 200
	PlayerState.force_set_stat_val("health", health_max)
	PlayerState.force_set_stat_val("money", money_max)
	Logging.info("TutorialController: [init 2/9] 健康=%d 钱财=%d（满值开局）" % [health_max, money_max])

	# 🆕 禁用 hover（由 tut_dialogue_4 事件启用）
	HoverPopupManager.set_hover_enabled(false)
	Logging.info("TutorialController: [init 3/9] hover 已禁用")

	# 🆕 用白名单控制行动面板：叙事阶段隐藏所有按钮
	_set_whitelist([])
	Logging.info("TutorialController: [init 4/9] 白名单已清空（叙事阶段）")

	# 连接信号
	_connect_tutorial_signals()
	Logging.info("TutorialController: [init 5/9] 信号已连接")

	# 注入 AnimationController timeline_scripts
	_inject_timeline_scripts()
	Logging.info("TutorialController: [init 6/9] timeline_scripts 已注入")

	# 递归记录所有控件可见性快照，然后隐藏所有 UI 面板
	_record_all_visibility(get_tree().root)
	Logging.info("TutorialController: [init 6.5/9] UI 可见性快照已记录")
	_hide_all_panels()
	Logging.info("TutorialController: [init 7/9] UI 面板已隐藏")

	# 初始地点设为泰山脚下，而非继承存档的西市
	PlayerState.stay_place = "taishan_base"
	Logging.info("TutorialController: [init 8/9] stay_place 已设为 taishan_base（泰山脚下）")

	PlayerState.force_set_stat_val("_time", 2)
	Logging.info("TutorialController: [init 9/9] _time 强制设为 2（days_per_xun=2）")

	# 道士初始状态由 NPCDocument 的 person_state="not_meet" 决定
	# 相遇后由 _advance_to_phase_2() 升级到 know_about
	Logging.info("TutorialController: [init] 道士初始 person_state=not_meet（NPCDocument 默认值）")

	# 开始 PHASE_1
	Logging.info("TutorialController: 全部初始化完成，即将进入 PHASE_1_MEET")
	call_deferred("_begin_phase_1")


# ═══════════════════════════════════════════════════════════
# 信号连接/断开
# ═══════════════════════════════════════════════════════════

func _connect_tutorial_signals() -> void:
	if _signals_connected:
		return

	if not EventBus.event_confirmed.is_connected(_on_event_confirmed):
		EventBus.event_confirmed.connect(_on_event_confirmed)
		Logging.info("TutorialController: 已连接 EventBus.event_confirmed")

	if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)
		Logging.info("TutorialController: 已连接 TimeService.on_xun_tick")

	# ── request_refresh_action_panel: 非事件路径 UI 状态检查 ──
	# 白名单变化 / 聚焦退出 / 预留行动 / DSL 显式刷新 等触发
	# ⚠️ event_confirmed 由 _on_event_confirmed 独占处理，不可同时连 _on_state_check
	# 否则会导致同一帧内 _on_event_confirmed 推进状态后 _on_state_check 误判当前 step
	if not EventBus.request_refresh_action_panel.is_connected(_on_state_check):
		EventBus.request_refresh_action_panel.connect(_on_state_check)
		Logging.info("TutorialController: 已连接 EventBus.request_refresh_action_panel -> _on_state_check")

	if not EventBus.event_confirmed.is_connected(_on_poem_created):
		EventBus.event_confirmed.connect(_on_poem_created)
		Logging.info("TutorialController: 已连接 EventBus.poems_created")

	if not PlayerState.stay_place_changed.is_connected(_on_stay_place_changed):
		PlayerState.stay_place_changed.connect(_on_stay_place_changed)
		Logging.info("TutorialController: 已连接 PlayerState.stay_place_changed")

	if not EventBus.exit_poem_page.is_connected(_on_poem_start_clicked):
		EventBus.exit_poem_page.connect(_on_poem_start_clicked)
		Logging.info("TutorialController: 已连接 EventBus.exit_poem_page")
	
	EventBus.idea_page_close.connect(end)

	_signals_connected = true


func _disconnect_tutorial_signals() -> void:
	if not _signals_connected:
		return
	if EventBus.event_confirmed.is_connected(_on_event_confirmed):
		EventBus.event_confirmed.disconnect(_on_event_confirmed)
	if TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.disconnect(_on_xun_tick)
	if EventBus.request_refresh_action_panel.is_connected(_on_state_check):
		EventBus.request_refresh_action_panel.disconnect(_on_state_check)
	if EventBus.event_confirmed.is_connected(_on_poem_created):
		EventBus.event_confirmed.disconnect(_on_poem_created)
	if PlayerState.stay_place_changed.is_connected(_on_stay_place_changed):
		PlayerState.stay_place_changed.disconnect(_on_stay_place_changed)
	if EventBus.exit_poem_page.is_connected(_on_poem_start_clicked):
		EventBus.exit_poem_page.disconnect(_on_poem_start_clicked)
	_signals_connected = false
	Logging.info("TutorialController: 所有信号已断开")


# ═══════════════════════════════════════════════════════════
# 行动可见性管理（白名单机制 — 不依赖 block/unblock）
# ═══════════════════════════════════════════════════════════

## 设置 tutorial 模式下可见的 action_id 白名单，并请求面板刷新。
## 空数组 = 隐藏所有主行动按钮。
func _set_whitelist(action_ids: Array[String]) -> void:
	Logging.info("TutorialController: [p4_step=%s(%d)] 白名单 → %s" % [_p4_step_name(), _p4_step, str(action_ids)])
	ActionManager.set_tutorial_visible_actions(action_ids)
	EventBus.request_refresh_action_panel.emit()
	Logging.info("TutorialController: 已请求刷新行动面板")

## 设置子行动白名单（控制 Picker 中哪些子行动可见）
func _set_sub_whitelist(sub_action_ids: Array[String]) -> void:
	Logging.info("TutorialController: [p4_step=%s(%d)] 子白名单 → %s" % [_p4_step_name(), _p4_step, str(sub_action_ids)])
	ActionManager.set_tutorial_visible_sub_actions(sub_action_ids)
	EventBus.request_refresh_action_panel.emit()


## 将 Phase4Step 枚举转为可读名称
func _p4_step_name() -> String:
	match _p4_step:
		Phase4Step.VAST_WORLD: return "VAST_WORLD"
		Phase4Step.FREE_ROAM: return "FREE_ROAM"
		Phase4Step.MOVED_AWAY: return "MOVED_AWAY"
		Phase4Step.FOG_FOUND: return "FOG_FOUND"
		Phase4Step.CHUYOU_VIEWED: return "CHUYOU_VIEWED"
		Phase4Step.BACK_AT_TAOIST: return "BACK_AT_TAOIST"
		Phase4Step.OVERRIDE_LOCKED: return "OVERRIDE_LOCKED"
		Phase4Step.OVERRIDE_READY: return "OVERRIDE_READY"
		_: return "UNKNOWN(%d)" % _p4_step


func _clear_all_tut_flags() -> void:
	"""清除所有 tutorial 相关的 flag"""
	var tut_flags := [
		"tut_lock_chuyou_subs",
		"tut_unlock_chuyou_subs", "tut_unlock_duzhuo",
		"tut_phase_started", "tut_fog_found",
	]
	for flag in tut_flags:
		PlayerState.set_flag(flag, false)
	Logging.info("TutorialController: 所有 tutorial flag 已清除")


## 🆕 将 tutorial 特有的 action 加入全局黑名单。
## tutorial 结束后这些行动在正常游戏中不应出现。
## 必须在 _restore_game_save_snapshot() 之后调用，否则会被旧快照覆盖。
func _ban_tutorial_actions() -> void:
	var tut_uuids := [
		# ── 出游（父行动 + 5 个方向子行动）──
		"tut_chuyou",           # 父行动 → 整个出游不显示
		"tut_chuyou_east",
		"tut_chuyou_west",
		"tut_chuyou_south",
		"tut_chuyou_north",
		"tut_chuyou_lookup",
		# ── 独酌（喝药酒子行动）──
		"tut_duzhuo_heyaojiu",
		# ── 交游（和道人说话 + 共饮）──
		"tut_jiaoyou_talk",
		"tut_jiaoyou_drink",
		# ── 驻留（泰山两个地点子行动）──
		"tut_zhu_liu_base",
		"tut_zhu_liu_upper",
	]
	for uuid in tut_uuids:
		ActionManager.add_hidden_action(uuid)
	Logging.info("TutorialController: 已将 %d 个 tutorial 特有 action 加入全局黑名单" % tut_uuids.size())


# ═══════════════════════════════════════════════════════════
# 道士 NPC 状态管理
# ═══════════════════════════════════════════════════════════

func _set_taoist_meditating() -> void:
	"""道士进入打坐状态（not_meet，玩家不能交互）"""
	RelationFlagManager.set_person_state(TAOIST_NPC_KEY, "not_meet")
	Logging.info("TutorialController: 道士 person_state → not_meet（打坐中）")

# ═══════════════════════════════════════════════════════════
# 公开 API
# ═══════════════════════════════════════════════════════════

func is_tutorial_active() -> bool:
	#breakpoint
	var active = not PlayerState.has_flag("tutorial_completed")
	return active

func get_current_phase() -> Phase:
	return _current_phase


# ═══════════════════════════════════════════════════════════
# UI 面板管理
# ═══════════════════════════════════════════════════════════

## 递归记录 Main 节点下所有 CanvasItem 及其子节点的 visible 状态。
## 快照存入 _visibility_snapshot：{node.get_path(): bool}
func _record_all_visibility(root_node: Node) -> void:
	_visibility_snapshot.clear()
	if not root_node:
		Logging.err("TutorialController: _record_all_visibility — root_node 为空")
		return
	# 从 Main 节点开始，避免遍历引擎内部节点导致输出洪泛
	var main_node := root_node.get_node_or_null("Main")
	if not main_node:
		Logging.err("TutorialController: _record_all_visibility — Main 节点不存在")
		return
	_record_visibility_recursive(main_node)
	Logging.info("TutorialController: UI 可见性快照已记录，共 %d 个控件" % _visibility_snapshot.size())


## 递归核心：遍历 node 及其所有子孙 CanvasItem，记录 visible 状态（不打逐条 debug 避免输出洪泛）
func _record_visibility_recursive(node: Node) -> void:
	if not node:
		return
	if node is CanvasItem:
		_visibility_snapshot[str(node.get_path())] = node.visible
	for child in node.get_children():
		_record_visibility_recursive(child)


## 根据 _visibility_snapshot 还原所有控件的 visible 状态。
func _restore_all_visibility(root_node: Node) -> void:
	if _visibility_snapshot.is_empty():
		Logging.info("TutorialController: _restore_all_visibility — 快照为空，跳过还原")
		return
	if not root_node:
		Logging.err("TutorialController: _restore_all_visibility — root_node 为空")
		return
	var restored_count: int = 0
	var missing_count: int = 0
	for node_path_str in _visibility_snapshot:
		var saved_visible: bool = _visibility_snapshot[node_path_str]
		var target := root_node.get_node_or_null(node_path_str)
		if target:
			if target is CanvasItem:
				target.visible = saved_visible
				restored_count += 1
		else:
			missing_count += 1
	Logging.info("TutorialController: UI 可见性已还原 — 成功=%d, 缺失=%d, 总计=%d" % [restored_count, missing_count, _visibility_snapshot.size()])
	_visibility_snapshot.clear()


## 保存 GameSave.data 的完整快照（tutorial 开始前调用）。
func _record_game_save_snapshot() -> void:
	_game_save_snapshot = GameSave.data.to_dict()
	Logging.info("TutorialController: 游戏存档快照已记录，共 %d 个 key" % _game_save_snapshot.size())


## 将 _game_save_snapshot 替换回 GameSave.data（tutorial 结束时调用）。
func _restore_game_save_snapshot() -> void:
	if _game_save_snapshot.is_empty():
		Logging.info("TutorialController: _restore_game_save_snapshot — 快照为空，跳过还原")
		return
	GameSave.data.from_dict(_game_save_snapshot)
	Logging.info("TutorialController: 游戏存档快照已还原，共 %d 个 key" % _game_save_snapshot.size())
	_game_save_snapshot.clear()


func _hide_all_panels() -> void:
	var tree := get_tree()
	if not tree:
		return
	var root := tree.root
	if not root:
		return
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return
	var left_panel := main_node.get_node_or_null("UI/Margin/HBox/LeftPanel") as Control
	var right_panel := main_node.get_node_or_null("UI/Margin/HBox/RightPanel") as Control
	if left_panel:
		left_panel.visible = false
	if right_panel:
		right_panel.visible = false
		# 隐藏右下四个功能按钮（社交、理念、作诗、记事）
		var hbox = right_panel.get_node_or_null("Panel/V/PanelContainer2/HBoxContainer")
		if hbox:
			for btn in hbox.get_children():
				btn.visible = false
	# 重置 LeftPanel 内部属性可见性
	if left_panel and left_panel.has_method("_hide_all_properties_tutorial"):
		left_panel._hide_all_properties_tutorial()
	Logging.info("TutorialController: 所有 UI 面板已隐藏")


func _ensure_all_ui_visible() -> void:
	var left_panel = _get_left_panel()
	if left_panel and left_panel.has_method("_show_all_properties"):
		left_panel._show_all_properties()
		Logging.info("TutorialController: 已调用 LeftPlayerPanel._show_all_properties()")
	# 确保左右面板可见
	var tree := get_tree()
	if tree and tree.root:
		var main_node := tree.root.get_node_or_null("Main")
		if main_node:
			var lp := main_node.get_node_or_null("UI/Margin/HBox/LeftPanel") as Control
			var rp := main_node.get_node_or_null("UI/Margin/HBox/RightPanel") as Control
			if lp:
				lp.visible = true
			if rp:
				rp.visible = true
				if rp.has_method("set_time_panel_visible"):
					rp.set_time_panel_visible(true)
				if rp.has_method("set_rumors_section_visible"):
					rp.set_rumors_section_visible(true)
				if rp.has_method("set_decisions_section_visible"):
					rp.set_decisions_section_visible(true)
				if rp.has_method("set_bottom_btn_bar_visible"):
					rp.set_bottom_btn_bar_visible(true)
				if rp.has_method("set_special_label_visible"):
					rp.set_special_label_visible(true)
	Logging.info("TutorialController: 非 tutorial 模式，UI 默认全部可见")


func _get_left_panel() -> Control:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return null
	return main_node.get_node_or_null("UI/Margin/HBox/LeftPanel") as Control


func _get_right_panel() -> Control:
	var tree := get_tree()
	if not tree:
		return null
	var root := tree.root
	if not root:
		return null
	var main_node := root.get_node_or_null("Main")
	if not main_node:
		return null
	return main_node.get_node_or_null("UI/Margin/HBox/RightPanel") as Control


# ═══════════════════════════════════════════════════════════
# 信号回调
# ═══════════════════════════════════════════════════════════

func _on_event_confirmed() -> void:
	if not is_tutorial_active():
		return
	Logging.info("TutorialController: event_confirmed — phase=%d p4_step=%s(%d) p5_step=%d p6_step=%d p7_step=%d" % [
		_current_phase, _p4_step_name(), _p4_step, _p5_step, _p6_step, _p7_step
	])

	match _current_phase:
		Phase.PHASE_1_MEET:
			_advance_to_phase_2()

		Phase.PHASE_2_DIALOGUE:
			_advance_dialogue()

		Phase.PHASE_4_EXPLORE:
			_on_phase_4_event_confirmed()

		Phase.PHASE_5_DEFER:
			_on_phase_5_event_confirmed()

		Phase.PHASE_6_VISION:
			_on_phase_6_event_confirmed()

		Phase.PHASE_7_POEM:
			_on_phase_7_event_confirmed()

		_:
			Logging.info("TutorialController: event_confirmed 在 phase=%d 无对应处理" % _current_phase)


func _on_xun_tick() -> void:
	if not is_tutorial_active():
		return

	var ta = TimeOperator.new()
	ta.refresh_time_to = 2
	ta.operate()

	if _current_phase == Phase.PHASE_5_DEFER:
		if _defer_started:
			Logging.info("TutorialController: xun_tick — Phase 5 defer 进行中, is_deferring=%s" % str(ActionManager.is_deferring("tut_taoist_dispel_fog")))
			if not ActionManager.is_deferring("tut_taoist_dispel_fog"):
				_defer_started = false
				_defer_completed = true
				Logging.info("TutorialController: xun_tick — defer 已完成！→ 进入 Phase 6")
				_advance_to_phase_6()
		else:
			if ActionManager.is_deferring("tut_taoist_dispel_fog"):
				_defer_started = true
				Logging.info("TutorialController: xun_tick — defer 已启动！解锁出游4方向")
				PlayerState.set_flag("tut_unlock_chuyou_subs", true)
				PlayerState.set_flag("tut_lock_chuyou_subs", false)
				_set_sub_whitelist([])
				_show_special_label("道长开始做法驱散云雾，需要两旬时间…去周边转转吧！点击「出游」探索四方")
			else:
				Logging.info("TutorialController: xun_tick — Phase 5 等待玩家点击驱散云雾启动 defer")
		return

	Logging.info("TutorialController: xun_tick — phase=%d p4_step=%s(%d), _defer_started=%s, 无 defer 相关处理" % [
		_current_phase, _p4_step_name(), _p4_step, str(_defer_started)
	])


func _on_state_check(_unused = null) -> void:
	if not is_tutorial_active():
		return
	Logging.info("TutorialController: state_check — phase=%d p4_step=%d" % [
		_current_phase, _p4_step
	])

	match _current_phase:
		Phase.PHASE_4_EXPLORE:
			_on_phase_4_action()
		Phase.PHASE_5_DEFER:
			_on_phase_5_action()
		Phase.PHASE_6_VISION:
			_on_phase_6_action()
		_:
			Logging.info("TutorialController: state_check 在 phase=%d 无特殊处理" % _current_phase)


func _on_stay_place_changed(place_str: String) -> void:
	if not is_tutorial_active():
		return
	Logging.info("TutorialController: stay_place_changed → '%s' — phase=%d p4_step=%s(%d)" % [
		place_str, _current_phase, _p4_step_name(), _p4_step
	])

	# Phase 4: 玩家迁移后触发雾事件
	if _current_phase == Phase.PHASE_4_EXPLORE and _p4_step == Phase4Step.FREE_ROAM:
		Logging.info("TutorialController: [P4:FREE_ROAM] 检测到迁移 → 推送雾事件 tut_move_away")
		_p4_step = Phase4Step.MOVED_AWAY
		PlayerState.set_flag("tut_fog_found", true)
		_push_tut_event("tut_move_away")


func _on_poem_created(_data: Array = []) -> void:
	if not is_tutorial_active():
		return
	
	if not PlayerState.created_poems.size() > 0:
		return

	Logging.info("TutorialController: poems_created — phase=%d p7_step=%d" % [
		_current_phase, _p7_step
	])

	if _current_phase == Phase.PHASE_7_POEM:
		_poem_created = true
		if _p7_step == Phase7Step.POEM_BTN_VISIBLE or _p7_step == Phase7Step.DRINK_WINE:
			# 诗词创作完成 → 推评论事件
			Logging.info("TutorialController: 诗词创作完成 → 推送 tut_poem_review")
			_p7_step = Phase7Step.POEM_REVIEWED
			_push_tut_event("tut_poem_review")


# ═══════════════════════════════════════════════════════════
# Phase 4 信号处理（自由探索阶段 — 行动驱动）
# ═══════════════════════════════════════════════════════════

func _on_phase_4_event_confirmed() -> void:
	Logging.info("TutorialController: Phase 4 event_confirmed — step=%s(%d)" % [_p4_step_name(), _p4_step])

	match _p4_step:
		Phase4Step.VAST_WORLD:
			# vast_world 确认 → 进入自由行动模式
			Logging.info("TutorialController: [P4:VAST_WORLD] vast_world 确认 → 进入自由行动模式")
			_p4_step = Phase4Step.FREE_ROAM
			# 道士进入打坐状态
			_set_taoist_meditating()
			# 仅显示交游 + 驻留
			_set_whitelist(["jiao_you", "zhu_liu"])
			_set_sub_whitelist(["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
			Logging.info("TutorialController: FREE_ROAM — 交游+驻留已解锁, 子行动: tut_jiaoyou_talk, 驻留2地点")
			_show_special_label("道长正在打坐…先在附近转转吧。点击右侧「交游」或「驻留」按钮开始探索")

		Phase4Step.MOVED_AWAY, Phase4Step.FOG_FOUND:
			# tut_move_away 确认 → 解锁出游（仅查看）
			Logging.info("TutorialController: [P4:MOVED_AWAY/FOG_FOUND] 雾事件确认 → 解锁出游按钮（仅查看，无4方向子行动）")
			_p4_step = Phase4Step.CHUYOU_VIEWED
			_set_whitelist(["jiao_you", "zhu_liu", "tut_chuyou"])
			# P3-1: FOG_FOUND 阶段不暴露出游4方向，defer 期间通过 flag 控制解锁
			_set_sub_whitelist(["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
			Logging.info("TutorialController: FOG_FOUND — 出游已解锁（仅查看模式）")
			_show_special_label("山雾弥漫，看不清山顶…或许道长知道些什么？点击「出游」查看")

		Phase4Step.CHUYOU_VIEWED:
			# 出游查看后 → 提示回找道士（道士保持 not_meet，共饮后才升级）
			Logging.info("TutorialController: [P4:CHUYOU_VIEWED] 出游查看后 → 准备回找道士，道士仍为 not_meet")
			_p4_step = Phase4Step.BACK_AT_TAOIST
			# 不调 _set_taoist_available() — 道士保持 not_meet，共饮后才 upgrade_person_state → know_about
			_push_tut_event("tut_return_taoist")

		Phase4Step.BACK_AT_TAOIST:
			# tut_return_taoist 确认 → override 可见但锁定
			Logging.info("TutorialController: [P4:BACK_AT_TAOIST] 回找道士确认 → override 锁定态")
			_p4_step = Phase4Step.OVERRIDE_LOCKED
			_set_whitelist(["jiao_you", "zhu_liu"])
			_show_special_label("与道长关系还不够密切…试试请他喝酒？点击「交游」→「共饮」")
			_set_sub_whitelist(["tut_jiaoyou_drink", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
			# tut_jiaoyou_drink 是 jiao_you 的普通子行动，不依赖 NPC 关系即可显示
			# tut_taoist_dispel_fog 是覆盖 tut_jiaoyou_drink 的 override，需要关系 >= know_about

		Phase4Step.OVERRIDE_LOCKED:
				Logging.info("TutorialController: [P4:OVERRIDE_LOCKED] 共饮确认，关系升级 → 直接进入 Phase 5")
				RelationFlagManager.upgrade_person_state(TAOIST_NPC_KEY)
				_p4_step = Phase4Step.OVERRIDE_READY
				_current_phase = Phase.PHASE_5_DEFER
				_p5_step = Phase5Step.DEFERRING
				_defer_started = false
				Logging.info("TutorialController: [P5] 已进入 Phase 5, _defer_started=false")
				_show_special_label("道长愿意帮你了！点击「交游」→ 请道长驱散云雾")

		_:
			Logging.warn("TutorialController: Phase 4 未处理的 event_confirmed step=%s(%d)" % [_p4_step_name(), _p4_step])


func _on_phase_4_action() -> void:
	Logging.info("TutorialController: Phase 4 state_check — step=%d" % _p4_step)

	if _p4_step == Phase4Step.FREE_ROAM:
		# 玩家在 FREE_ROAM 阶段点了行动，检查是不是交游（打坐无回应）
		# 交游的 fallback 事件在 tut_jiaoyou_drink 中配置
		# 如果失败，走的是 fallback_event_uuid
		Logging.info("TutorialController: Phase 4 FREE_ROAM — 行动已执行，等待事件确认或迁移")

	elif _p4_step == Phase4Step.OVERRIDE_LOCKED:
		if ActionManager.is_deferring("tut_taoist_dispel_fog"):
			Logging.info("TutorialController: [P4:OVERRIDE_LOCKED] defer 已启动，直接进入 Phase 5")
			_advance_to_phase_5()
		else:
			Logging.info("TutorialController: [P4:OVERRIDE_LOCKED] defer 尚未启动，等待 event_confirmed")
	elif _p4_step == Phase4Step.OVERRIDE_READY:
		# P0-4: 玩家点击了 override（驱散云雾）→ 进入 Phase 5
		Logging.info("TutorialController: OVERRIDE_READY — 玩家点击了 override，进入 Phase 5")
		_advance_to_phase_5()


# ═══════════════════════════════════════════════════════════
# Phase 5 信号处理（Override + Defer）
# ═══════════════════════════════════════════════════════════

func _on_phase_5_action() -> void:
	Logging.info("TutorialController: Phase 5 state_check — step=%d, _just_entered=%s" % [_p5_step, str(_just_entered_phase_5)])

	if _just_entered_phase_5:
		# 🆕 刚进入 Phase 5，_set_sub_whitelist 触发 request_refresh_action_panel → _on_state_check
		# 此时 defer 尚未被 SubActionExecutor 启动，跳过中断检测
		_just_entered_phase_5 = false
		Logging.info("TutorialController: Phase 5 刚进入，跳过首次 state_check 检测")
		return
		
	elif _p5_step == Phase5Step.DEFER_INTERRUPTED:
		# defer 中断事件已确认 → 重新开始 defer
		Logging.info("TutorialController: defer 中断确认 → 重新启动 defer")
		_defer_started = true
		_defer_completed = false
		_p5_step = Phase5Step.DEFERRING
		_show_special_label("道长重新开始做法…这次别再打断了。点击「出游」探索周边")


# ═══════════════════════════════════════════════════════════
# Phase 5 event_confirmed
# ═══════════════════════════════════════════════════════════

func _on_phase_5_event_confirmed() -> void:
	Logging.info("TutorialController: Phase 5 event_confirmed — step=%d" % _p5_step)


# ═══════════════════════════════════════════════════════════
# Phase 6 信号处理（泰山显现）
# ═══════════════════════════════════════════════════════════

func _on_phase_6_action() -> void:
	Logging.info("TutorialController: Phase 6 state_check — step=%d（无白名单驱动逻辑）" % _p6_step)


# ═══════════════════════════════════════════════════════════
# Phase 6 event_confirmed
# ═══════════════════════════════════════════════════════════

func _on_phase_6_event_confirmed() -> void:
	Logging.info("TutorialController: Phase 6 event_confirmed — step=%d" % _p6_step)
	if _p6_step == Phase6Step.DEFER_DONE_EVENT:
		# tut_defer_done 确认 → 解锁"往上看"
		Logging.info("TutorialController: tut_defer_done 确认 → 「往上看」可用")
		_p6_step = Phase6Step.LOOK_UP_READY
		_just_entered_lookup_ready = true
		_show_special_label("云雾已散！点击「出游」→ 往山顶看看")

	elif _p6_step == Phase6Step.LOOK_UP_READY:
		if _just_entered_lookup_ready:
			# 🆕 tut_defer_done 的 choice_result 后果（set_stay_place 等）会在同一事件链内
			# 额外 emit event_confirmed，跳过此次，不误触「往上看确认」
			Logging.info("TutorialController: Phase 6 LOOK_UP_READY 守卫 — 跳过 tut_defer_done 后果的 event_confirmed")
			_just_entered_lookup_ready = false
		else:
			# 玩家点了"往上看" → 事件确认 → 获取最后 Lv3 意象 → Phase 7
			Logging.info("TutorialController: 往上看确认 → 获得最后意象 → Phase 7")
			_p6_step = Phase6Step.FINAL_IMAGINARY
			_show_special_label("泰山之巅尽收眼底！点击右下角蓝色印章，将感悟化为诗句")
			_advance_to_phase_7()


# ═══════════════════════════════════════════════════════════
# Phase 7 信号处理（诗词创作 + 理念）
# ═══════════════════════════════════════════════════════════

func _on_phase_7_event_confirmed() -> void:
	Logging.info("TutorialController: Phase 7 event_confirmed — step=%d" % _p7_step)

	#breakpoint
	match _p7_step:
		Phase7Step.NO_INSPIRATION:
			# 兴不足事件确认 → 解锁独酌
			Logging.info("TutorialController: 兴不足确认 → 解锁独酌（喝药酒）")
			_p7_step = Phase7Step.DRINK_WINE
			PlayerState.set_flag("tut_unlock_duzhuo", true)
			PlayerState.set_flag("tut_lock_duzhuo", false)
			_set_whitelist(["du_zhuo"])
			_set_sub_whitelist(["tut_duzhuo_heyaojiu"])
			_show_special_label("喝点药酒提提神吧！点击「闲居」→「喝药酒」")
		Phase7Step.DRINK_WINE:
			# 玩家喝了药酒 → 事件确认 → 检查兴是否恢复
			var inspiration = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
			Logging.info("TutorialController: 喝药酒后 event_confirmed — 兴=%d" % inspiration)
			if inspiration > 0:
				_inspiration_gained = true
				_show_special_label("文思如泉涌！点击右下角毛笔按钮，开始写诗吧")
			else:
				Logging.warn("TutorialController: 喝药酒后兴仍为0，检查 duzhuo_heyaojiu action 是否正确配置")

		Phase7Step.POEM_REVIEWED:
			# 道人评诗确认 → 解锁理念
			Logging.info("TutorialController: 评诗确认 → 解锁理念按钮")
			_p7_step = Phase7Step.IDEA_UNLOCKED
			_show_special_label("道长对你的诗赞不绝口！点击右下角蓝色印章，确立你的远大志向")
			

		Phase7Step.IDEA_UNLOCKED:
			# P2-1: 理念解锁 → 先推 tut_idea_unlock 事件（展示理念按钮）
			Logging.info("TutorialController: 理念解锁 → 推送 tut_idea_unlock")
			_p7_step = Phase7Step.FINAL_REVEAL_DONE
			_push_tut_event("tut_idea_unlock")

		Phase7Step.FINAL_REVEAL_DONE:
			# tut_idea_unlock 确认 → 推送 tut_final_reveal（揭示最后 UI）
			Logging.info("TutorialController: idea_unlock 确认 → 推送 tut_final_reveal")
			_p7_step = Phase7Step.AWAIT_ENDING
			_push_tut_event("tut_final_reveal")
		_:
			Logging.warn("TutorialController: Phase 7 未处理的 event_confirmed step=%d" % _p7_step)

func end():
	if _p7_step == Phase7Step.AWAIT_ENDING:
		# tut_final_reveal 确认 → 进入 END
		Logging.info("TutorialController: final_reveal 确认 → 进入 END")
		_advance_to_end()

func _on_poem_start_clicked() -> void:
	#breakpoint
	if not is_tutorial_active():
		return
	if _current_phase != Phase.PHASE_7_POEM:
		return
	if _p7_step != Phase7Step.POEM_BTN_VISIBLE:
		return
	var inspiration = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
	Logging.info("TutorialController: poem_start_clicked — 兴=%d" % inspiration)
	if inspiration <= 0:
		Logging.info("TutorialController: 兴=0 → 推送 tut_no_inspiration")
		_p7_step = Phase7Step.NO_INSPIRATION
		_push_tut_event("tut_no_inspiration")

# ═══════════════════════════════════════════════════════════
# 状态机推进（Phase 级别）
# ═══════════════════════════════════════════════════════════

func _advance_to_phase_2() -> void:
	_current_phase = Phase.PHASE_2_DIALOGUE
	_dialogue_step = 0
	# 道士保持 not_meet（相遇≠相识），共饮后才升级到 know_about
	Logging.info("TutorialController: PHASE_1_MEET → PHASE_2_DIALOGUE, 道士仍为 not_meet")
	_push_tut_event(DIALOGUE_EVENTS[_dialogue_step])


func _advance_dialogue() -> void:
	_dialogue_step += 1
	if _dialogue_step < DIALOGUE_EVENTS.size():
		Logging.info("TutorialController: PHASE_2 step %d/%d" % [_dialogue_step + 1, DIALOGUE_EVENTS.size()])
		_push_tut_event(DIALOGUE_EVENTS[_dialogue_step])
	else:
		# tut_dialogue_4 已合并 trait_add(strong_body) + prop_add(health+50)
		# 直接进入 PHASE_4_EXPLORE，跳过 PHASE_3_TRAIT
		Logging.info("TutorialController: PHASE_2_DIALOGUE → PHASE_4_EXPLORE（已跳过 PHASE_3_TRAIT）")
		_current_phase = Phase.PHASE_4_EXPLORE
		_p4_step = Phase4Step.VAST_WORLD
		_push_tut_event("tut_vast_world")


func _advance_to_phase_5() -> void:
	Logging.info("TutorialController: ====== PHASE_4_EXPLORE → PHASE_5_DEFER ======")
	_current_phase = Phase.PHASE_5_DEFER
	_p5_step = Phase5Step.DEFERRING
	_defer_started = false
	Logging.info("TutorialController: [P5] p5_step=DEFERRING, _defer_started=false（等待 xun_tick 检测 defer）")
	_set_sub_whitelist([])


func _advance_to_phase_6() -> void:
	Logging.info("TutorialController: ====== PHASE_5_DEFER → PHASE_6_VISION ======")
	_current_phase = Phase.PHASE_6_VISION
	_p6_step = Phase6Step.DEFER_DONE_EVENT
	_set_whitelist(["jiao_you", "zhu_liu", "tut_chuyou"])
	_set_sub_whitelist(["tut_chuyou_lookup"])
	Logging.info("TutorialController: [P6] p6_step=DEFER_DONE_EVENT, 白名单=[jiao_you,zhu_liu,tut_chuyou], 子白名单=[tut_chuyou_lookup]")
	_push_tut_event("tut_defer_done")


func _advance_to_phase_7() -> void:
	Logging.info("TutorialController: ====== PHASE_6_VISION → PHASE_7_POEM ======")
	_current_phase = Phase.PHASE_7_POEM
	_p7_step = Phase7Step.POEM_BTN_VISIBLE
	_set_whitelist([])
	_set_sub_whitelist([])
	# 🆕 强制归零兴 — 生存系统每旬 +3 兴会在教程前期累积
	# 不清零则 PoemCrafter 检查通过，跳过 tut_no_inspiration 分支
	PlayerState.force_set_stat_val("inspiration", 0)
	Logging.info("TutorialController: [P7] 兴已归零，白名单=[]（全禁，等待 tut_no_inspiration 后解锁独酌）")
	_show_special_label("面对壮丽山河，何不赋诗一首？点击右下角毛笔按钮开始创作")


func _advance_to_end() -> void:
	"""无法事件期间触发"""
	Logging.info("TutorialController: ====== PHASE_7_POEM → END ======")
	_current_phase = Phase.END
	_disconnect_tutorial_signals()
	ActionManager.clear_tutorial_whitelist()
	ActionManager.clear_tutorial_sub_whitelist()
	_clear_all_tut_flags()
	TimeService.reset_days_per_xun()

	# 🆕 还原游戏存档快照（覆盖 tutorial 期间所有修改）
	_restore_game_save_snapshot()
	Logging.info("TutorialController: 游戏存档快照已还原（覆盖 tutorial 期间所有状态变更）")
	PlayerState.set_flag("tutorial_completed", true, 'bool')
	# 🆕 全局黑名单：ban 掉 tutorial 特有的子行动（必须在快照还原之后，否则会被覆盖）
	_ban_tutorial_actions()

	# 🆕 根据快照递归还原所有控件可见性
	_restore_all_visibility(get_tree().root)
	Logging.info("TutorialController: UI 可见性已根据快照还原")
	# 兜底：调用 _ensure_all_ui_visible 刷新面板内部状态（属性列表、时间面板、风闻等）
	_ensure_all_ui_visible()
	Logging.info("TutorialController: _ensure_all_ui_visible 已调用（兜底刷新）")

	# 🆕 恢复 hover
	HoverPopupManager.set_hover_enabled(true)
	Logging.info("TutorialController: hover 已恢复")
	Logging.info("TutorialController: tutorial 完成！days_per_xun 已恢复默认，所有信号已断开，白名单已清除")
	TimeService.jump_to_clean(745.0)
	EventBus.request_refresh_action_panel.emit()
	EventBus.show_mid_panel.emit()
	


# ═══════════════════════════════════════════════════════════
# 各 Phase 进入逻辑
# ═══════════════════════════════════════════════════════════

func _begin_phase_1() -> void:
	_on_xun_tick()
	Logging.info("TutorialController: === 开始 PHASE_1_MEET ===")
	PlayerState.set_flag("tut_phase_started", "phase_1")
	_current_phase = Phase.PHASE_1_MEET
	_push_tut_event("tut_meet_taoist")


# ═══════════════════════════════════════════════════════════
# 辅助方法
# ═══════════════════════════════════════════════════════════

func _push_tut_event(event_key: String) -> void:
	Logging.info("TutorialController: 推送事件 '%s'" % event_key)
	EventBus.request_event_key.emit(event_key, {
		"tutorial": true,
		"tutorial_phase": _current_phase,
	})


func _show_special_label(text: String) -> void:
	"""直接设置 RightInfoPanel 上 Control/SpecialLabel 的文本"""
	Logging.info("TutorialController: SpecialLabel → '%s'" % text)
	var right_panel := _get_right_panel()
	right_panel.set_special_label_text(text)


# ═══════════════════════════════════════════════════════════
# AnimationController timeline_scripts 注入
# ═══════════════════════════════════════════════════════════

func _inject_timeline_scripts() -> void:
	var scripts: Dictionary = {
		# PHASE_1: 鸟语花香音效（无UI变化）
		"tut_meet_taoist": [
			{ "delay": 0.0, "action": "play_sound", "target": "", "sound_path": "res://assets/sounds/property/imaginary_gain_t1.ogg", "volume_db": -10.0 },
		],

		# PHASE_2 Step 1: 道士问大名 → 展示名字+地点+身份
		"tut_dialogue_1": [
			{ "delay": 0.0, "action": "show_panel", "target": "left_panel" },
			{ "delay": 0.0, "action": "set_left_section_visible", "target": "name", "visible": true },
			{ "delay": 0.0, "action": "set_left_section_visible", "target": "place", "visible": true },
			{ "delay": 0.0, "action": "set_left_section_visible", "target": "identity", "visible": true },
		],

		# PHASE_2 Step 2: 道士问时间 → 展示时间面板（含刷新）
		"tut_dialogue_time": [
			{ "delay": 0.0, "action": "show_panel", "target": "right_panel" },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "time_panel", "visible": true },
			{ "delay": 0.1, "action": "refresh_time_panel", "target": "right_panel" },
		],

		# PHASE_2 Step 3: 谈身板 → 展示健康+钱财（满值）
		"tut_dialogue_2": [
			{ "delay": 0.0, "action": "set_prop_visible", "target": "left_panel", "prop_key": "health", "visible": true },
			{ "delay": 0.0, "action": "set_prop_visible", "target": "left_panel", "prop_key": "money", "visible": true },
		],

		# PHASE_2 Step 4: 强身之道+身强体壮（合并）→ 展示 TraitGrid + 启用 hover
		# trait_add(strong_body) + prop_add(health+50) 在 tut_dialogue_4.tres 的 choice_result 中执行
		"tut_dialogue_4": [
			{ "delay": 0.0, "action": "set_trait_grid_visible", "target": "left_panel", "visible": true },
			{ "delay": 0.0, "action": "set_hover_enabled", "target": "", "enabled": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "bottom_btn_bar", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "social_btn", "visible": true },
		],

		# PHASE_6: 云开雾散 → poem_btn 可见
		"tut_defer_done": [
			{ "delay": 0.5, "action": "show_special_label", "target": "right_panel", "text": "云雾消散，泰山之巅显现！点击右下角毛笔按钮开始写诗" },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "poem_btn", "visible": true },
		],

		# PHASE_7a: 诗词创作后 → 名望行可见
		"tut_poem_review": [
			{ "delay": 0.0, "action": "set_prop_visible", "target": "left_panel", "prop_key": "prestige", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "idea_btn", "visible": true },
		],

		# P2-2: tut_idea_unlock — 理念按钮可见（确认后由 final_reveal 揭示剩余 UI）
		"tut_idea_unlock": [
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "idea_btn", "visible": true },
		],

		# 🆕 最后揭示：风闻 + 决议 + 底层修饰 + 底部按钮栏 + SpecialLabel
		"tut_final_reveal": [
			{ "delay": 0.0, "action": "set_left_section_visible", "target": "bottom_decoration", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "rumors_section", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "decisions_section", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "bottom_btn_bar", "visible": true },
			{ "delay": 0.0, "action": "set_special_label_visible", "target": "right_panel", "visible": true },
		],
	}

	for uuid in scripts:
		AnimationController.timeline_scripts[uuid] = scripts[uuid]
	Logging.info("TutorialController: 已注入 %d 个 timeline_scripts" % scripts.size())
