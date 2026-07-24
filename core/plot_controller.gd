extends Node
## PlotController — Autoload，根据 event_counter + xun_tick 推动主线剧情
##
## 职责：
##   1. 监听 TimeService.on_xun_tick，累计 xun 次数
##   2. 在第 3 旬时，检查 event_counter == 2，触发同乡来访事件
##   3. 监控 progress 属性：>30 触发骊山事件，>60 触发结冰渭河事件
##   4. 通过 flag_bool 持久化防重复触发

# ════════════════════════════════════════════════════════════════
# 常量
# ════════════════════════════════════════════════════════════════

const TRIGGER_XUN: int = 3
const REQUIRED_EVENT_COUNT: int = 2
const PLOT_EVENT_KEY: String = "plot_prompt_user_action"
const FLAG_TRIGGERED: String = "plot_prompt_user_action_triggered"

## 🆕 755_backhome 时代 progress 阈值事件
const EVENT_LISHAN: String = "backhome_lishan_1"
const EVENT_INDIFFERENT_WIND: String = "backhome_indifferent_wind_1"
const EVENT_LOST_TOY: String = "backhome_lost_toy_1"
const EVENT_FENGXIAN_VILLAGE: String = "fengxian_village_entrance"
const FLAG_LISHAN_TRIGGERED: String = "plot_lishan_triggered"
const FLAG_INDIFFERENT_WIND_TRIGGERED: String = "plot_indifferent_wind_triggered"
const FLAG_LOST_TOY_TRIGGERED: String = "plot_lost_toy_triggered"
const FLAG_FENGXIAN_TRIGGERED: String = "plot_fengxian_triggered"
const PROGRESS_LISHAN_THRESHOLD: int = 21  # >30
const PROGRESS_INDIFFERENT_WIND_THRESHOLD: int = 41  # >60
const PROGRESS_LOST_TOY_THRESHOLD: int = 61  # >=79
const PROGRESS_FENGXIAN_THRESHOLD: int = 100  # >=100 → 抵达奉先村口

# ════════════════════════════════════════════════════════════════
# 内部状态
# ════════════════════════════════════════════════════════════════

var _xun_count: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 注册防重复触发的 flag（bool 型，存在即表示已触发）
	PlayerState.register_virtual_flag(FLAG_LISHAN_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LISHAN_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_INDIFFERENT_WIND_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_INDIFFERENT_WIND_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_LOST_TOY_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LOST_TOY_TRIGGERED)

	# 🆕 回家结局路由 flag：玩家在骊山是否选择了「死死盯住冻死骨」
	PlayerState.register_virtual_flag("flag_witnessed_lishan_corpses", "bool")
	Logging.info("[PlotController] 注册虚拟 flag: flag_witnessed_lishan_corpses")
	PlayerState.register_virtual_flag(FLAG_FENGXIAN_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_FENGXIAN_TRIGGERED)

	# 监听每旬 tick（同乡来访触发）
	if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)
		Logging.info("[PlotController] 已连接 TimeService.on_xun_tick")

	# 🆕 监听 progress 属性变化，立即检查阈值
	if not PlayerState.player_stat_changed.is_connected(_on_stat_changed):
		PlayerState.player_stat_changed.connect(_on_stat_changed)
		Logging.info("[PlotController] 已连接 PlayerState.player_stat_changed")

	Logging.info("[PlotController] Autoload 初始化完成")


# ════════════════════════════════════════════════════════════════
# 每旬回调
# ════════════════════════════════════════════════════════════════

func _on_xun_tick() -> void:
	if TutorialController.is_tutorial_active():
		Logging.info("[PlotController] tutorial 模式，跳过同乡来访检查")
		return
	_xun_count += 1
	Logging.info("[PlotController] 第 %d 旬 tick, event_counter=%d" % [_xun_count, GameState.event_counter])

	# ── 检查同乡来访触发（原有逻辑）──
	_check_town_folk_trigger()

	# ── 🆕 检查 progress 阈值触发 ──
	_check_progress_triggers()


# ════════════════════════════════════════════════════════════════
# 同乡来访触发
# ════════════════════════════════════════════════════════════════

func _check_town_folk_trigger() -> void:
	if _xun_count != TRIGGER_XUN:
		Logging.info("[PlotController] xun_count=%d ≠ %d，跳过同乡来访触发检查" % [_xun_count, TRIGGER_XUN])
		return

	if GameState.event_counter < REQUIRED_EVENT_COUNT:
		Logging.info("[PlotController] event_counter=%d < %d，跳过同乡来访触发" % [GameState.event_counter, REQUIRED_EVENT_COUNT])
		return

	if PlayerState.has_flag(FLAG_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过重复触发" % FLAG_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发剧情事件: %s ═══" % PLOT_EVENT_KEY)
	PlayerState.set_flag(FLAG_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_TRIGGERED)
	EventBus.push_event.emit(PLOT_EVENT_KEY, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % PLOT_EVENT_KEY)


# ════════════════════════════════════════════════════════════════
# 🆕 progress 阈值触发（755_backhome 时代）
# ════════════════════════════════════════════════════════════════

# 🆕 progress 属性变化回调（即时触发，不等 xun tick）
func _on_stat_changed(prop_name: String) -> void:
	if prop_name != "progress":
		return
	if TutorialController.is_tutorial_active():
		Logging.info("[PlotController] tutorial 模式，跳过 progress 变化检查")
		return
	Logging.info("[PlotController] progress 属性变化检测到: prop_name=%s，触发阈值检查" % prop_name)
	_check_progress_triggers()

func _check_progress_triggers() -> void:
	var progress_val: int = PlayerState.get_stat_val("progress")
	Logging.info("[PlotController] progress 检查: current=%d, lishan_threshold=%d, wind_threshold=%d, lost_toy_threshold=%d" % [
		progress_val, PROGRESS_LISHAN_THRESHOLD, PROGRESS_INDIFFERENT_WIND_THRESHOLD, PROGRESS_LOST_TOY_THRESHOLD
	])

	# 骊山触发：progress > 30
	if progress_val >= PROGRESS_LISHAN_THRESHOLD:
		if not PlayerState.has_flag(FLAG_LISHAN_TRIGGERED):
			Logging.info("[PlotController] ═══ progress=%d > 30，触发骊山事件: %s ═══" % [progress_val, EVENT_LISHAN])
			PlayerState.set_flag(FLAG_LISHAN_TRIGGERED, true)
			Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LISHAN_TRIGGERED)
			EventBus.push_event.emit(EVENT_LISHAN, {})
			Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LISHAN)
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过骊山触发" % FLAG_LISHAN_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达骊山阈值 %d，跳过" % [progress_val, PROGRESS_LISHAN_THRESHOLD])

	# 结冰渭河触发：progress > 60
	if progress_val >= PROGRESS_INDIFFERENT_WIND_THRESHOLD:
		if not PlayerState.has_flag(FLAG_INDIFFERENT_WIND_TRIGGERED):
			Logging.info("[PlotController] ═══ progress=%d > 60，触发结冰渭河事件: %s ═══" % [progress_val, EVENT_INDIFFERENT_WIND])
			PlayerState.set_flag(FLAG_INDIFFERENT_WIND_TRIGGERED, true)
			Logging.info("[PlotController] flag '%s' 已设置" % FLAG_INDIFFERENT_WIND_TRIGGERED)
			EventBus.push_event.emit(EVENT_INDIFFERENT_WIND, {})
			Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_INDIFFERENT_WIND)
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过结冰渭河触发" % FLAG_INDIFFERENT_WIND_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达结冰渭河阈值 %d，跳过" % [progress_val, PROGRESS_INDIFFERENT_WIND_THRESHOLD])
		
	# 🆕 遗失拨浪鼓触发：progress >= 79 且玩家持有 rattle_drum trait
	if progress_val >= PROGRESS_LOST_TOY_THRESHOLD:
		if not PlayerState.has_flag(FLAG_LOST_TOY_TRIGGERED):
			if PlayerState.has_trait("rattle_drum"):
				Logging.info("[PlotController] ═══ progress=%d >= %d 且持有 rattle_drum，触发遗失玩具事件: %s ═══" % [progress_val, PROGRESS_LOST_TOY_THRESHOLD, EVENT_LOST_TOY])
				PlayerState.set_flag(FLAG_LOST_TOY_TRIGGERED, true)
				Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LOST_TOY_TRIGGERED)
				EventBus.push_event.emit(EVENT_LOST_TOY, {})
				Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LOST_TOY)
			else:
				Logging.info("[PlotController] progress=%d >= %d 但玩家没有 rattle_drum trait，跳过遗失玩具触发" % [progress_val, PROGRESS_LOST_TOY_THRESHOLD])
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过遗失玩具触发" % FLAG_LOST_TOY_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达遗失玩具阈值 %d，跳过" % [progress_val, PROGRESS_LOST_TOY_THRESHOLD])

	# 奉先村口触发：progress >= 100
	if progress_val >= PROGRESS_FENGXIAN_THRESHOLD:
		if not PlayerState.has_flag(FLAG_FENGXIAN_TRIGGERED):
			Logging.info("[PlotController] ═══ progress=%d >= %d，触发奉先村入口事件: %s ═══" % [progress_val, PROGRESS_FENGXIAN_THRESHOLD, EVENT_FENGXIAN_VILLAGE])
			PlayerState.set_flag(FLAG_FENGXIAN_TRIGGERED, true)
			Logging.info("[PlotController] flag '%s' 已设置" % FLAG_FENGXIAN_TRIGGERED)
			EventBus.push_event.emit(EVENT_FENGXIAN_VILLAGE, {})
			Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_FENGXIAN_VILLAGE)
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过奉先村入口触发" % FLAG_FENGXIAN_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达奉先村阈值 %d，跳过" % [progress_val, PROGRESS_FENGXIAN_THRESHOLD])
