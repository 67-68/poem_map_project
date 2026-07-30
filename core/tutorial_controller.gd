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
	PHASE_1_MEET,            # 道士出场 + 鸟语花香音效
	PHASE_2_DIALOGUE,        # 对话 + 面板滑入 + 属性揭示（含 trait+health+50）
	PHASE_4_EXPLORE,         # 自由探索（行动驱动）
	PHASE_IMAGERY_COLLECT,   # 意象收集（共饮后、驱散云雾前）— 收集3意象→写诗→道长评诗→P5
	PHASE_5_DEFER,           # override + defer 驱散云雾
	PHASE_6_VISION,          # 往上看 + 最后 Lv3 意象
	PHASE_7_POEM,            # 诗词创作 + 理念解锁
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

# ── 意象收集 子阶段 ──
enum ImageryStep {
	FREE_ROAM,               # 仅出游(南/北/西/凝视)+驻留可用
	IMAGERY_READY,           # 意象≥3 → poem_btn 出现 + special_label
	POEM_WRITTEN,            # 写诗完成 → 提示回找道士
}

# ── Phase 5 子阶段 ──
enum Phase5Step {
	DEFERRING,               # defer 进行中（由 _advance_to_phase_5() 进入）
	DEFER_INTERRUPTED,       # 玩家中断 defer
	DEFER_DONE,              # defer 完成
}

# ── Phase 6 子阶段 ──
enum Phase6Step {
	DEFER_DONE_EVENT,     # tut_defer_done 展示中
	LOOK_UP_READY,        # tr("CODE_TUTORIAL_CONTROLLER_3171C95644")可用
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

# ── 意象收集子阶段 ──
var _img_step: ImageryStep = ImageryStep.FREE_ROAM

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
var _phase_1_intro_shown: bool = false

# ── Task 注册入口（tutorial 初始化时创建，各 Phase 转换点注入）──
var _task_dengding: Task = null            # "登顶" (is_manual_complete)
var _task_climb_up: Task = null            # "上山腰看看"
var _task_look_around: Task = null         # "四处看看"
var _task_return_taoist: Task = null       # "回去找道士"
var _task_dispel_fog: Task = null          # "拨开雾气"
var _task_drink: Task = null               # "和道士喝酒"
var _task_collect_imagery: Task = null     # "收集意象"
var _task_write_poem: Task = null          # "写诗词"
var _task_climb_mountain: Task = null      # "登山" (Phase 6)
var _task_write_final_poem: Task = null    # "写诗词" (Phase 7)
var _tasks_initialized: bool = false
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
	PlayerState.register_virtual_flag("tut_lock_chuyou_subs", "bool")
	PlayerState.register_virtual_flag("tut_unlock_chuyou_subs", "bool")
	PlayerState.register_virtual_flag("tut_unlock_duzhuo", "bool")
	PlayerState.register_virtual_flag("tut_phase_started", "str")
	PlayerState.register_virtual_flag("tut_fog_found", "bool")
	PlayerState.register_virtual_flag("tut_lock_duzhuo", "bool")


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
	# TimeService.jump_to_clean(745.0)
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
	EventBus.narrative_tape_show_requested.emit()
	EventBus.request_event_key.emit("event_intro_745", {})
 
func _begin_tutorial() -> void:
	Logging.info("TutorialController: ====== 开始新手教程 ======")

	# 🆕 保存游戏存档快照（tutorial 结束后完整还原）
	_record_game_save_snapshot()
	Logging.info("TutorialController: [init 0/9] 游戏存档快照已记录")

	# 🆕 注册 tutorial 任务树
	_init_tasks()
	Logging.info("TutorialController: [init 0.5/9] 任务树已初始化")

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
	
	if not EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.connect(_on_imaginary_changed)
		Logging.info("TutorialController: 已连接 EventBus.imaginary_changed")
	
	_connect_task_callbacks()
	
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
	if EventBus.imaginary_changed.is_connected(_on_imaginary_changed):
		EventBus.imaginary_changed.disconnect(_on_imaginary_changed)
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
	var tut_flags := [
		"tut_lock_chuyou_subs",
		"tut_unlock_chuyou_subs", "tut_unlock_duzhuo", "tut_lock_duzhuo",
		"tut_phase_started", "tut_fog_found",
	]
	for flag in tut_flags:
		PlayerState.set_flag(flag, false)
	Logging.info("TutorialController: 所有 tutorial flag 已清除")
	RelationFlagManager.set_person_state("tut_taoist",RelationFlagManager.PERSON_STATE.UNCHARTED)


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
		"tut_chuyou_gaze",
		# ── 独酌（喝药酒子行动）──
		"tut_duzhuo_heyaojiu",
		# ── 交游（和道人说话 + 共饮）──
		"tut_jiaoyou_talk",
		"tut_jiaoyou_drink",
		# ── 驻留（泰山两个地点子行动）──
		"tut_zhu_liu_base",
		"tut_zhu_liu_upper",
		"tut_taoist_dispel_fog"
	]
	for uuid in tut_uuids:
		ActionManager.add_hidden_action(uuid)
	Logging.info("TutorialController: 已将 %d 个 tutorial 特有 action 加入全局黑名单" % tut_uuids.size())


# ═══════════════════════════════════════════════════════════
# 道士 NPC 状态管理
# ═══════════════════════════════════════════════════════════

func _set_taoist_meditating() -> void:
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
			if not _phase_1_intro_shown:
				# 第一步：背景介绍确认 → 推道士出场事件
				_phase_1_intro_shown = true
				Logging.info("TutorialController: tut_background_intro 确认 → 推送 tut_meet_taoist")
				_push_tut_event("tut_meet_taoist")
			else:
				# 第二步：道士出场确认 → 进入对话阶段
				_advance_to_phase_2()

		Phase.PHASE_2_DIALOGUE:
			_advance_dialogue()

		Phase.PHASE_4_EXPLORE:
			_on_phase_4_event_confirmed()

		Phase.PHASE_IMAGERY_COLLECT:
			_on_imagery_collect_event_confirmed()

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
				_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_24F0B161F7"))
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
		Phase.PHASE_IMAGERY_COLLECT:
			_on_imagery_collect_action()
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
		# 🆕 手动完成 "四处看看" 任务
		TaskManager.complete_current_task()
		_push_tut_event("tut_move_away")
	
	# 意象收集 Phase: POEM_WRITTEN 阶段玩家迁回 taishan_base 后触发回找道士
	if _current_phase == Phase.PHASE_IMAGERY_COLLECT and _img_step == ImageryStep.POEM_WRITTEN and place_str == "taishan_base":
		Logging.info("TutorialController: [IMAGERY:POEM_WRITTEN] 检测到 player 迁回 taishan_base → 推送 tut_poem_to_taoist，道士 not_meet→know_about")
		RelationFlagManager.upgrade_person_state(TAOIST_NPC_KEY)
		_push_tut_event("tut_poem_to_taoist")


func _on_poem_created(_data: Array = []) -> void:
	if not is_tutorial_active():
		return
	
	if not PlayerState.created_poems.size() > 0:
		return

	Logging.info("TutorialController: poems_created — phase=%d img_step=%d p7_step=%d" % [
		_current_phase, _img_step, _p7_step
	])

	# 意象收集阶段写诗（第一次：无名诗词）
	if _current_phase == Phase.PHASE_IMAGERY_COLLECT and _img_step == ImageryStep.IMAGERY_READY:
		_poem_created = true
		Logging.info("TutorialController: 意象收集阶段诗词创作完成 → POEM_WRITTEN")
		_img_step = ImageryStep.POEM_WRITTEN
		# 切白名单：仅交游+驻留可用，诗人迁回泰山脚下找道士
		_set_whitelist(["jiao_you", "zhu_liu"])
		_set_sub_whitelist(["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
		_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_IMAGERY_POEM_WRITTEN"))
		return

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
			# 🆕 注入"上山腰看看"子任务
			_inject_task_climb_up()
			Logging.info("TutorialController: FREE_ROAM — 交游+驻留已解锁, 子行动: tut_jiaoyou_talk, 驻留2地点")
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_93E7E727A3"))

		Phase4Step.MOVED_AWAY, Phase4Step.FOG_FOUND:
			# tut_move_away 确认 → 解锁出游（仅查看）
			Logging.info("TutorialController: [P4:MOVED_AWAY/FOG_FOUND] 雾事件确认 → 解锁出游按钮（仅查看，无4方向子行动）")
			_p4_step = Phase4Step.CHUYOU_VIEWED
			_set_whitelist(["jiao_you", "zhu_liu", "tut_chuyou"])
			# P3-1: FOG_FOUND 阶段暴露出游4方向（仅查看，四周看雾）; lookup 留给 Phase 6
			# FOG_FOUND: 仅暴露东方向探索（其余方向在 Phase 5 defer 期间由 flag 解锁）
			_set_sub_whitelist(["tut_jiaoyou_talk", "tut_zhu_liu_base", "tut_zhu_liu_upper", "tut_chuyou_east"])
			Logging.info("TutorialController: FOG_FOUND — 出游已解锁（仅查看模式）")
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_095EFAB7C8"))

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
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_16EFDC16D7"))
			_set_sub_whitelist(["tut_jiaoyou_drink", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
			# tut_jiaoyou_drink 是 jiao_you 的普通子行动，不依赖 NPC 关系即可显示
			# tut_taoist_dispel_fog 是覆盖 tut_jiaoyou_drink 的 override，需要关系 >= know_about

		Phase4Step.OVERRIDE_LOCKED:
				Logging.info("TutorialController: [P4:OVERRIDE_LOCKED] 共饮确认，道士质疑文采 → 推送 tut_collect_imagery")
				RelationFlagManager.upgrade_person_state(TAOIST_NPC_KEY)
				_p4_step = Phase4Step.OVERRIDE_READY
				_push_tut_event("tut_collect_imagery")

		Phase4Step.OVERRIDE_READY:
				Logging.info("TutorialController: [P4:OVERRIDE_READY] tut_collect_imagery 确认 → 进入意象收集 Phase")
				_advance_to_imagery_collect()

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
		_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_ED9554CBC2"))


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
		_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_40AB2EDE13"))

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
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_492C9E4D68"))
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
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_BC3D3B02C0"))
		Phase7Step.DRINK_WINE:
			# 玩家喝了药酒 → 事件确认 → 检查兴是否恢复
			var inspiration = PlayerState.get_stat_val(ENUMS.PROPS.INSPIRATION)
			Logging.info("TutorialController: 喝药酒后 event_confirmed — 兴=%d" % inspiration)
			if inspiration > 0:
				_inspiration_gained = true
				_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_0AE2169679"))
			else:
				Logging.warn("TutorialController: 喝药酒后兴仍为0，检查 duzhuo_heyaojiu action 是否正确配置")

		Phase7Step.POEM_REVIEWED:
			# 道人评诗确认 → 解锁理念
			Logging.info("TutorialController: 评诗确认 → 解锁理念按钮")
			_p7_step = Phase7Step.IDEA_UNLOCKED
			_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_ACE0C1BEC6"))
			

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
	
	# 意象收集阶段写诗按钮：在 IMAGERY_READY 已可见，点击正常进入写诗流程
	if _current_phase == Phase.PHASE_IMAGERY_COLLECT and _img_step == ImageryStep.IMAGERY_READY:
		Logging.info("TutorialController: poem_start_clicked in IMAGERY_READY — 正常进入写诗流程")
		# 不拦截，让默认行为（写诗 UI 打开）正常执行
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
		# 🆕 第二步对话（tut_dialogue_2 — 道士问来意）→ 注入"登顶"任务
		if _dialogue_step == 2:
			_inject_task_dengding()
		_push_tut_event(DIALOGUE_EVENTS[_dialogue_step])
	else:
		# tut_dialogue_4 已合并 trait_add(strong_body) + prop_add(health+50)
		# 直接进入 PHASE_4_EXPLORE，跳过 PHASE_3_TRAIT
		Logging.info("TutorialController: PHASE_2_DIALOGUE → PHASE_4_EXPLORE（已跳过 PHASE_3_TRAIT）")
		_current_phase = Phase.PHASE_4_EXPLORE
		_p4_step = Phase4Step.VAST_WORLD
		_push_tut_event("tut_vast_world")


# ═══════════════════════════════════════════════════════════
# 意象收集 Phase 信号处理
# ═══════════════════════════════════════════════════════════

## 进入意象收集 Phase（tut_collect_imagery 确认后调用）
func _advance_to_imagery_collect() -> void:
	Logging.info("TutorialController: ====== P4 → PHASE_IMAGERY_COLLECT ======")
	_current_phase = Phase.PHASE_IMAGERY_COLLECT
	_img_step = ImageryStep.FREE_ROAM
	# 仅出游(南/北/西/凝视) + 驻留可用；东和 lookup 不可见
	_set_whitelist(["tut_chuyou", "zhu_liu"])
	_set_sub_whitelist(["tut_chuyou_south", "tut_chuyou_north", "tut_chuyou_west", "tut_chuyou_gaze", "tut_zhu_liu_base", "tut_zhu_liu_upper"])
	_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_IMAGERY_COLLECT_FREE"))
	Logging.info("TutorialController: [IMAGERY:FREE_ROAM] 白名单: tut_chuyou+zhu_liu; 子白名单: south/north/west/gaze + zhu_liu_base/upper")


## imaginary_changed 信号回调 — 检测意象数量是否 >= 3
func _on_imaginary_changed() -> void:
	if not is_tutorial_active():
		return
	if _current_phase != Phase.PHASE_IMAGERY_COLLECT:
		return
	if _img_step != ImageryStep.FREE_ROAM:
		Logging.info("TutorialController: _on_imaginary_changed — 不在 FREE_ROAM 子阶段，跳过")
		return
	
	var count := Database.imaginaries_detail.size()
	Logging.info("TutorialController: _on_imaginary_changed — 当前意象数量=%d, 阈值=3" % count)
	if count >= 3:
		Logging.info("TutorialController: [IMAGERY:FREE_ROAM] 意象数量达标 → IMAGERY_READY")
		_img_step = ImageryStep.IMAGERY_READY
		# poem_btn 可见 + 提示写诗（直接访问 Poembtn 节点，与 AnimationController 同路径）
		var rp := _get_right_panel()
		if rp:
			var poem_btn := rp.get_node_or_null("Panel/V/PanelContainer2/HBoxContainer/Poembtn") as Control
			if poem_btn:
				poem_btn.visible = true
				Logging.info("TutorialController: poem_btn (Poembtn) 已设置为可见")
			else:
				Logging.err("TutorialController: 未找到 Poembtn 节点")
		_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_IMAGERY_READY"))
		EventBus.request_refresh_action_panel.emit()


## 意象收集 Phase event_confirmed 处理
func _on_imagery_collect_event_confirmed() -> void:
	Logging.info("TutorialController: ImageryCollection event_confirmed — step=%d" % _img_step)
	
	if _img_step == ImageryStep.POEM_WRITTEN:
		# tut_poem_to_taoist 确认 → 进入 Phase 5
		Logging.info("TutorialController: tut_poem_to_taoist 确认 → 进入 Phase 5")
		_current_phase = Phase.PHASE_5_DEFER
		_p5_step = Phase5Step.DEFERRING
		_defer_started = false
		_set_whitelist(["jiao_you", "zhu_liu"])
		_set_sub_whitelist([])
		_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_179CB8FB4E"))
		Logging.info("TutorialController: [P5] 已进入 Phase 5, _defer_started=false, 白名单=[jiao_you,zhu_liu], 子白名单=[]")


## 意象收集 Phase state_check 处理
func _on_imagery_collect_action() -> void:
	Logging.info("TutorialController: ImageryCollection state_check — step=%d" % _img_step)


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
	_show_special_label(tr("CODE_TUTORIAL_CONTROLLER_343A3514E3"))


func _advance_to_end() -> void:
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
	# TimeService.jump_to_clean(745.0)
	EventBus.request_refresh_action_panel.emit()
	EventBus.show_mid_panel.emit()
	EventBus.request_event_key.emit("event_intro_745", {})
	


# ═══════════════════════════════════════════════════════════
# 各 Phase 进入逻辑
# ═══════════════════════════════════════════════════════════

func _begin_phase_1() -> void:
	_on_xun_tick()
	Logging.info("TutorialController: === 开始 PHASE_1_MEET ===")
	PlayerState.set_flag("tut_phase_started", "phase_1")
	_current_phase = Phase.PHASE_1_MEET
	_push_tut_event("tut_background_intro")


# ═══════════════════════════════════════════════════════════
# 🆕 Task 系统 — 初始化和链式回调
# ═══════════════════════════════════════════════════════════

func _init_tasks() -> void:
	if _tasks_initialized:
		return
	_tasks_initialized = true

	# ── ParentA: "登顶" (is_manual_complete, 无requirement) ──
	_task_dengding = Task.new()
	_task_dengding.name = tr("CODE_TUT_TASK_DENGDING")
	_task_dengding.description = tr("CODE_TUT_TASK_DENGDING_DESC")
	_task_dengding.is_manual_complete = true
	_task_dengding.uuid = "tut_task_dengding"

	# ── ChildA1: "上山腰看看" ──
	_task_climb_up = Task.new()
	_task_climb_up.name = tr("CODE_TUT_TASK_CLIMB_UP")
	_task_climb_up.description = tr("CODE_TUT_TASK_CLIMB_UP_DESC")
	_task_climb_up.uuid = "tut_task_climb_up"
	var climb_req := PlaceRequirement.new()
	climb_req.place = "taishan_upper"
	_task_climb_up.requirements = [climb_req]

	# ── ChildA2: "四处看看" ──
	_task_look_around = Task.new()
	_task_look_around.name = tr("CODE_TUT_TASK_LOOK_AROUND")
	_task_look_around.description = tr("CODE_TUT_TASK_LOOK_AROUND_DESC")
	_task_look_around.uuid = "tut_task_look_around"
	_task_look_around.is_manual_complete = true  # 由 TutorialController 手动完成

	# ── ChildA3: "回去找道士" ──
	_task_return_taoist = Task.new()
	_task_return_taoist.name = tr("CODE_TUT_TASK_RETURN_TAOIST")
	_task_return_taoist.description = tr("CODE_TUT_TASK_RETURN_TAOIST_DESC")
	_task_return_taoist.uuid = "tut_task_return_taoist"
	var return_req := PlaceRequirement.new()
	return_req.place = "taishan_base"
	_task_return_taoist.requirements = [return_req]

	# ── ParentB: "拨开雾气" ──
	_task_dispel_fog = Task.new()
	_task_dispel_fog.name = tr("CODE_TUT_TASK_DISPEL_FOG")
	_task_dispel_fog.description = tr("CODE_TUT_TASK_DISPEL_FOG_DESC")
	_task_dispel_fog.uuid = "tut_task_dispel_fog"

	# ── ChildB1: "和道士喝酒" ──
	_task_drink = Task.new()
	_task_drink.name = tr("CODE_TUT_TASK_DRINK")
	_task_drink.description = tr("CODE_TUT_TASK_DRINK_DESC")
	_task_drink.uuid = "tut_task_drink"
	var drink_req := PersonStateRequirement.new()
	drink_req.npc_key = "tut_taoist"
	drink_req.expected_state = "know_about"
	_task_drink.requirements = [drink_req]

	# ── ChildB2: "收集意象" ──
	_task_collect_imagery = Task.new()
	_task_collect_imagery.name = tr("CODE_TUT_TASK_COLLECT_IMAGERY")
	_task_collect_imagery.description = tr("CODE_TUT_TASK_COLLECT_IMAGERY_DESC")
	_task_collect_imagery.uuid = "tut_task_collect_imagery"
	var img_req := ImaginaryCountRequirement.new()
	img_req.threshold = 3
	_task_collect_imagery.requirements = [img_req]

	# ── ChildB3: "写诗词" ──
	_task_write_poem = Task.new()
	_task_write_poem.name = tr("CODE_TUT_TASK_WRITE_POEM")
	_task_write_poem.description = tr("CODE_TUT_TASK_WRITE_POEM_DESC")
	_task_write_poem.uuid = "tut_task_write_poem"
	var poem_req := PoemCountRequirement.new()
	poem_req.threshold = 1
	_task_write_poem.requirements = [poem_req]

	# ── ParentC: "登山顶" (chain_next after 拨开雾气) ──
	_task_climb_mountain = Task.new()
	_task_climb_mountain.name = tr("CODE_TUT_TASK_CLIMB_MOUNTAIN")
	_task_climb_mountain.description = tr("CODE_TUT_TASK_CLIMB_MOUNTAIN_DESC")
	_task_climb_mountain.uuid = "tut_task_climb_mountain"

	# ── ChildC1: "登山" ──
	var climb_act := Task.new()
	climb_act.name = tr("CODE_TUT_TASK_CLIMB_ACT")
	climb_act.description = tr("CODE_TUT_TASK_CLIMB_ACT_DESC")
	climb_act.uuid = "tut_task_climb_act"
	var climb_flag := FlagRequirement.new()
	climb_flag.flag_id = "tut_climbed_mountain"
	climb_flag.type = "bool"
	climb_flag.value = true
	climb_flag.operator = REQ_OPERATOR.COMPARE.EQUAL
	climb_act.requirements = [climb_flag]
	_task_climb_mountain.children.append(climb_act)

	# ── ChildC2: "写诗词" ──
	_task_write_final_poem = Task.new()
	_task_write_final_poem.name = tr("CODE_TUT_TASK_WRITE_FINAL_POEM")
	_task_write_final_poem.description = tr("CODE_TUT_TASK_WRITE_FINAL_POEM_DESC")
	_task_write_final_poem.uuid = "tut_task_write_final_poem"
	var final_poem_req := PoemCountRequirement.new()
	final_poem_req.threshold = 1
	_task_write_final_poem.requirements = [final_poem_req]
	_task_climb_mountain.children.append(_task_write_final_poem)

	Logging.info("TutorialController: 全部 %d 个 Task 已初始化" % 11)


# ═══════════════════════════════════════════════════════════
# 🆕 Task 链式回调 — 在各 Phase 转换点调用
# ═══════════════════════════════════════════════════════════

## Phase 1 对话中：道士问来意 → 注入"登顶"任务
func _inject_task_dengding() -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_dengding, TaskManager.SetMode.REPLACE_ROOT)
	Logging.info("TutorialController: [TASK] REPLACE_ROOT → '登顶'")


## Phase 4 VAST_WORLD→FREE_ROAM → 追加"上山腰看看"
func _inject_task_climb_up() -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_climb_up, TaskManager.SetMode.APPEND_TO_CHILDREN)
	Logging.info("TutorialController: [TASK] APPEND → '上山腰看看'")


## "上山腰看看" 完成 → 追加"四处看看"
func _on_task_climb_up_done(_task) -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_look_around, TaskManager.SetMode.APPEND_TO_CHILDREN)
	Logging.info("TutorialController: [TASK] APPEND → '四处看看'")


## "四处看看" 完成 → 追加"回去找道士"
func _on_task_look_around_done(_task) -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_return_taoist, TaskManager.SetMode.APPEND_TO_CHILDREN)
	Logging.info("TutorialController: [TASK] APPEND → '回去找道士'")


## "回去找道士" 完成 → REPLACE_ROOT → "拨开雾气"
func _on_task_return_taoist_done(_task) -> void:
	if not _tasks_initialized: return
	# "登顶"子树已全部完成，替换为"拨开雾气"
	_task_dispel_fog.children.clear()
	_task_dispel_fog.children.append(_task_drink)
	TaskManager.set_task(_task_dispel_fog, TaskManager.SetMode.REPLACE_ROOT)
	Logging.info("TutorialController: [TASK] REPLACE_ROOT → '拨开雾气' (含 '和道士喝酒')")


## "和道士喝酒" 完成 → 追加"收集意象"
func _on_task_drink_done(_task) -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_collect_imagery, TaskManager.SetMode.APPEND_TO_CHILDREN)
	Logging.info("TutorialController: [TASK] APPEND → '收集意象'")


## "收集意象" 完成 → 追加"写诗词"
func _on_task_collect_imagery_done(_task) -> void:
	if not _tasks_initialized: return
	TaskManager.set_task(_task_write_poem, TaskManager.SetMode.APPEND_TO_CHILDREN)
	Logging.info("TutorialController: [TASK] APPEND → '写诗词'")


## "写诗词" 完成 → "拨开雾气" 父任务也完成 → chain 到 "登山顶"
func _on_task_write_poem_done(_task) -> void:
	if not _tasks_initialized: return
	# "拨开雾气" 的子任务全部完成，它将在 _check_and_advance 中自动完成
	# 然后 chain_next → "登山顶"
	_task_dispel_fog.chain_next = _task_climb_mountain
	Logging.info("TutorialController: [TASK] 链接 chain_next → '登山顶'")


# 在 _connect_tutorial_signals 中额外连接 task_completed 信号（首次连接）
func _connect_task_callbacks() -> void:
	if not EventBus.task_completed.is_connected(_on_any_task_completed):
		EventBus.task_completed.connect(_on_any_task_completed)
		Logging.info("TutorialController: 已连接 EventBus.task_completed → _on_any_task_completed")


## 统一 task_completed 分发器：按 uuid 分派到具体回调
func _on_any_task_completed(task: Task) -> void:
	if not _tasks_initialized:
		return
	Logging.info("TutorialController: task_completed → '%s' (%s)" % [task.name, task.uuid])
	match task.uuid:
		"tut_task_climb_up":
			_on_task_climb_up_done(task)
		"tut_task_look_around":
			_on_task_look_around_done(task)
		"tut_task_return_taoist":
			_on_task_return_taoist_done(task)
		"tut_task_drink":
			_on_task_drink_done(task)
		"tut_task_collect_imagery":
			_on_task_collect_imagery_done(task)
		"tut_task_write_poem":
			_on_task_write_poem_done(task)
		_:
			Logging.info("TutorialController: task_completed 未处理 — '%s'" % task.uuid)


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

		# PHASE_2 Step 3: 谈身板 → 展示健康+钱财（满值），同时显示任务面板
		"tut_dialogue_2": [
			{ "delay": 0.0, "action": "set_prop_visible", "target": "left_panel", "prop_key": "health", "visible": true },
			{ "delay": 0.0, "action": "set_prop_visible", "target": "left_panel", "prop_key": "money", "visible": true },
			{ "delay": 0.0, "action": "set_task_container_visible", "target": "right_panel", "visible": true },
		],

		# PHASE_2 Step 4: 强身之道+身强体壮（合并）→ 展示 TraitGrid + 启用 hover
		# trait_add(strong_body) + prop_add(health+50) 在 tut_dialogue_4.tres 的 choice_result 中执行
		"tut_dialogue_4": [
			{ "delay": 0.0, "action": "set_trait_grid_visible", "target": "left_panel", "visible": true },
			{ "delay": 0.0, "action": "set_hover_enabled", "target": "", "enabled": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "bottom_btn_bar", "visible": true },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "social_btn", "visible": true },
		],

		# PHASE_6: 云开雾散 → poem_btn 可见 + 势望兴三属性揭示
		"tut_defer_done": [
			{ "delay": 0.5, "action": "show_special_label", "target": "right_panel", "text": tr("CODE_TUTORIAL_CONTROLLER_FF7E1A1C7B") },
			{ "delay": 0.0, "action": "set_right_section_visible", "target": "right_panel", "section": "poem_btn", "visible": true },
			{ "delay": 0.0, "action": "set_left_section_visible", "target": "ambition_section", "visible": true },
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
