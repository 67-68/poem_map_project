extends Node
## PlotController — Autoload，根据 event_counter + xun_tick 推动主线剧情
##
## 职责：
##   1. 监听 TimeService.on_xun_tick，累计 xun 次数
##   2. 在第 3 旬时，检查 event_counter == 2，触发同乡来访事件
##   3. 监控 progress 属性：>30 触发骊山事件，>60 触发结冰渭河事件
##   4. 旬5-8 触发李白酒肆劝退事件，旬15-20 触发街头科举情报事件
##   5. 🆕 天宝五载政治清洗线：旬6立仗马之诫、旬12韦坚案、旬18罗吉密探网、旬24李邕之死、旬28王忠嗣罢黜
##   6. 🆕 罗吉密探网激活后每旬30%概率检查兴>60触发酷吏找上门
##   7. 通过 flag_bool 持久化防重复触发

# ════════════════════════════════════════════════════════════════
# 常量
# ════════════════════════════════════════════════════════════════

const TRIGGER_XUN: int = 3
const REQUIRED_EVENT_COUNT: int = 2
const PLOT_EVENT_KEY: String = "plot_prompt_user_action"
const FLAG_TRIGGERED: String = "plot_prompt_user_action_triggered"

## 天宝六载「野无遗贤」前置剧情 — 旬窗口触发
const LIBAI_WARNING_EVENT: String = "libai_tavern_warning"
const LIBAI_WARNING_XUN_MIN: int = 5
const LIBAI_WARNING_XUN_MAX: int = 8
const FLAG_LIBAI_WARNING_TRIGGERED: String = "plot_libai_warning_triggered"

const STREET_RUMOR_EVENT: String = "street_exam_rumor"
const STREET_RUMOR_XUN_MIN: int = 15
const STREET_RUMOR_XUN_MAX: int = 20
const FLAG_STREET_RUMOR_TRIGGERED: String = "plot_street_rumor_triggered"

## 755_backhome 时代 progress 阈值事件
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
# 🆕 天宝五载政治清洗线常量
# ════════════════════════════════════════════════════════════════

## 立仗马之诫（约第6旬 / 745年秋）
const EVENT_LIJIANZHIMA: String = "event_lijianzhima"
const LIJIANZHIMA_XUN_MIN: int = 5
const LIJIANZHIMA_XUN_MAX: int = 8
const FLAG_LIJIANZHIMA_TRIGGERED: String = "plot_lijianzhima_triggered"

## 韦坚皇甫惟明案（约第12旬 / 746年春）
const EVENT_WEIJIAN: String = "event_weijian_case"
const WEIJIAN_XUN_MIN: int = 11
const WEIJIAN_XUN_MAX: int = 14
const FLAG_WEIJIAN_TRIGGERED: String = "plot_weijian_triggered"

## 罗吉密探网（约第18旬 / 746年夏）
const EVENT_LUOJI: String = "event_luoji_network"
const LUOJI_XUN_MIN: int = 17
const LUOJI_XUN_MAX: int = 20
const FLAG_LUOJI_TRIGGERED: String = "plot_luoji_triggered"

## 北海星坠·杖杀李邕（约第24旬 / 746年秋）
const EVENT_LIYONG: String = "event_liyong_death"
const LIYONG_XUN_MIN: int = 23
const LIYONG_XUN_MAX: int = 26
const FLAG_LIYONG_TRIGGERED: String = "plot_liyong_triggered"

## 罢黜王忠嗣（约第28旬 / 746年冬）
const EVENT_WANGZHONGSI: String = "event_wangzhongsi"
const WANGZHONGSI_XUN_MIN: int = 27
const WANGZHONGSI_XUN_MAX: int = 30
const FLAG_WANGZHONGSI_TRIGGERED: String = "plot_wangzhongsi_triggered"

## 罗吉密探网后续：酷吏找上门
const EVENT_LUOJI_PENALTY: String = "event_luoji_penalty"
const FLAG_LUOJI_ACTIVE: String = "flag_luoji_active"
const LUOJI_PENALTY_PCT: int = 30
const LUOJI_INSPIRATION_THRESHOLD: int = 60

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

	# 天宝六载剧情 flag
	PlayerState.register_virtual_flag(FLAG_LIBAI_WARNING_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LIBAI_WARNING_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_STREET_RUMOR_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_STREET_RUMOR_TRIGGERED)

	# 回家结局路由 flag：玩家在骊山是否选择了「死死盯住冻死骨」
	PlayerState.register_virtual_flag("flag_witnessed_lishan_corpses", "bool")
	Logging.info("[PlotController] 注册虚拟 flag: flag_witnessed_lishan_corpses")
	PlayerState.register_virtual_flag(FLAG_FENGXIAN_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_FENGXIAN_TRIGGERED)

	# 🆕 天宝五载政治清洗线 flag
	PlayerState.register_virtual_flag(FLAG_LIJIANZHIMA_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LIJIANZHIMA_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_WEIJIAN_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_WEIJIAN_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_LUOJI_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LUOJI_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_LIYONG_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LIYONG_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_WANGZHONGSI_TRIGGERED, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_WANGZHONGSI_TRIGGERED)
	PlayerState.register_virtual_flag(FLAG_LUOJI_ACTIVE, "bool")
	Logging.info("[PlotController] 注册虚拟 flag: %s" % FLAG_LUOJI_ACTIVE)

	# 监听每旬 tick（同乡来访触发）
	if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)
		Logging.info("[PlotController] 已连接 TimeService.on_xun_tick")

	# 监听 progress 属性变化，立即检查阈值
	if not PlayerState.player_stat_changed.is_connected(_on_stat_changed):
		PlayerState.player_stat_changed.connect(_on_stat_changed)
		Logging.info("[PlotController] 已连接 PlayerState.player_stat_changed")

	Logging.info("[PlotController] Autoload 初始化完成")


# ════════════════════════════════════════════════════════════════
# 每旬回调
# ════════════════════════════════════════════════════════════════

func _on_xun_tick() -> void:
	if TutorialController.is_tutorial_active():
		Logging.info("[PlotController] tutorial 模式，跳过剧情检查")
		return
	_xun_count += 1
	Logging.info("[PlotController] 第 %d 旬 tick, event_counter=%d" % [_xun_count, GameState.event_counter])

	# ── 检查同乡来访触发（原有逻辑）──
	_check_town_folk_trigger()

	# ── 天宝六载前置剧情：旬窗口触发 ──
	_check_libai_trigger()
	_check_rumor_trigger()

	# ── 🆕 天宝五载政治清洗线：旬窗口触发 ──
	_check_lijianzhima_trigger()
	_check_weijian_trigger()
	_check_luoji_trigger()
	_check_liyong_trigger()
	_check_wangzhongsi_trigger()

	# ── 🆕 罗吉密探网：每旬30%酷吏找上门检查 ──
	_check_luoji_penalty()

	# ── 检查 progress 阈值触发 ──
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
# progress 阈值触发（755_backhome 时代）
# ════════════════════════════════════════════════════════════════

# progress 属性变化回调（即时触发，不等 xun tick）
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
			EventBus.push_event_with_children.emit(EVENT_LISHAN, {})
			Logging.info("[PlotController] 已发射 push_event_with_children: %s" % EVENT_LISHAN)
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
			EventBus.push_event_with_children.emit(EVENT_INDIFFERENT_WIND, {})
			Logging.info("[PlotController] 已发射 push_event_with_children: %s" % EVENT_INDIFFERENT_WIND)
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过结冰渭河触发" % FLAG_INDIFFERENT_WIND_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达结冰渭河阈值 %d，跳过" % [progress_val, PROGRESS_INDIFFERENT_WIND_THRESHOLD])
		
	# 遗失拨浪鼓触发：progress >= 79 且玩家持有 rattle_drum trait
	if progress_val >= PROGRESS_LOST_TOY_THRESHOLD:
		if not PlayerState.has_flag(FLAG_LOST_TOY_TRIGGERED):
			if PlayerState.has_trait("rattle_drum"):
				Logging.info("[PlotController] ═══ progress=%d >= %d 且持有 rattle_drum，触发遗失玩具事件: %s ═══" % [progress_val, PROGRESS_LOST_TOY_THRESHOLD, EVENT_LOST_TOY])
				PlayerState.set_flag(FLAG_LOST_TOY_TRIGGERED, true)
				Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LOST_TOY_TRIGGERED)
				EventBus.push_event_with_children.emit(EVENT_LOST_TOY, {})
				Logging.info("[PlotController] 已发射 push_event_with_children: %s" % EVENT_LOST_TOY)
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
			EventBus.push_event_with_children.emit(EVENT_FENGXIAN_VILLAGE, {})
			Logging.info("[PlotController] 已发射 push_event_with_children: %s" % EVENT_FENGXIAN_VILLAGE)
		else:
			Logging.info("[PlotController] flag '%s' 已存在，跳过奉先村入口触发" % FLAG_FENGXIAN_TRIGGERED)
	else:
		Logging.info("[PlotController] progress=%d 未达奉先村阈值 %d，跳过" % [progress_val, PROGRESS_FENGXIAN_THRESHOLD])


# ════════════════════════════════════════════════════════════════
# 天宝六载「野无遗贤」前置剧情 — 旬窗口触发
# ════════════════════════════════════════════════════════════════

func _check_libai_trigger() -> void:
	Logging.info("[PlotController] _check_libai_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, LIBAI_WARNING_XUN_MIN, LIBAI_WARNING_XUN_MAX])
	if _xun_count < LIBAI_WARNING_XUN_MIN:
		Logging.info("[PlotController] xun_count=%d < %d，未达李白酒肆事件窗口下限" % [_xun_count, LIBAI_WARNING_XUN_MIN])
		return
	if _xun_count > LIBAI_WARNING_XUN_MAX:
		Logging.info("[PlotController] xun_count=%d > %d，已超出李白酒肆事件窗口上限" % [_xun_count, LIBAI_WARNING_XUN_MAX])
		return

	if PlayerState.has_flag(FLAG_LIBAI_WARNING_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过李白酒肆事件" % FLAG_LIBAI_WARNING_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发剧情事件: %s ═══" % LIBAI_WARNING_EVENT)
	PlayerState.set_flag(FLAG_LIBAI_WARNING_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LIBAI_WARNING_TRIGGERED)
	EventBus.push_event.emit(LIBAI_WARNING_EVENT, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % LIBAI_WARNING_EVENT)


func _check_rumor_trigger() -> void:
	Logging.info("[PlotController] _check_rumor_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, STREET_RUMOR_XUN_MIN, STREET_RUMOR_XUN_MAX])
	if _xun_count < STREET_RUMOR_XUN_MIN:
		Logging.info("[PlotController] xun_count=%d < %d，未达街头传言事件窗口下限" % [_xun_count, STREET_RUMOR_XUN_MIN])
		return
	if _xun_count > STREET_RUMOR_XUN_MAX:
		Logging.info("[PlotController] xun_count=%d > %d，已超出街头传言事件窗口上限" % [_xun_count, STREET_RUMOR_XUN_MAX])
		return

	if PlayerState.has_flag(FLAG_STREET_RUMOR_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过街头传言事件" % FLAG_STREET_RUMOR_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发剧情事件: %s ═══" % STREET_RUMOR_EVENT)
	PlayerState.set_flag(FLAG_STREET_RUMOR_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_STREET_RUMOR_TRIGGERED)
	EventBus.push_event.emit(STREET_RUMOR_EVENT, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % STREET_RUMOR_EVENT)


# ════════════════════════════════════════════════════════════════
# 🆕 天宝五载政治清洗线 — 旬窗口触发
# ════════════════════════════════════════════════════════════════

func _check_lijianzhima_trigger() -> void:
	Logging.info("[PlotController] _check_lijianzhima_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, LIJIANZHIMA_XUN_MIN, LIJIANZHIMA_XUN_MAX])
	if _xun_count < LIJIANZHIMA_XUN_MIN:
		return
	if _xun_count > LIJIANZHIMA_XUN_MAX:
		return
	if PlayerState.has_flag(FLAG_LIJIANZHIMA_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过立仗马之诫" % FLAG_LIJIANZHIMA_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发: %s ═══" % EVENT_LIJIANZHIMA)
	PlayerState.set_flag(FLAG_LIJIANZHIMA_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LIJIANZHIMA_TRIGGERED)
	# 设置持久标记：密探举报机制激活
	PlayerState.set_flag("flag_lijianzhima_active", true)
	Logging.info("[PlotController] 持久标记 flag_lijianzhima_active 已激活")
	EventBus.push_event.emit(EVENT_LIJIANZHIMA, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LIJIANZHIMA)


func _check_weijian_trigger() -> void:
	Logging.info("[PlotController] _check_weijian_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, WEIJIAN_XUN_MIN, WEIJIAN_XUN_MAX])
	if _xun_count < WEIJIAN_XUN_MIN:
		return
	if _xun_count > WEIJIAN_XUN_MAX:
		return
	if PlayerState.has_flag(FLAG_WEIJIAN_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过韦坚案" % FLAG_WEIJIAN_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发: %s ═══" % EVENT_WEIJIAN)
	PlayerState.set_flag(FLAG_WEIJIAN_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_WEIJIAN_TRIGGERED)
	EventBus.push_event.emit(EVENT_WEIJIAN, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_WEIJIAN)


func _check_luoji_trigger() -> void:
	Logging.info("[PlotController] _check_luoji_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, LUOJI_XUN_MIN, LUOJI_XUN_MAX])
	if _xun_count < LUOJI_XUN_MIN:
		return
	if _xun_count > LUOJI_XUN_MAX:
		return
	if PlayerState.has_flag(FLAG_LUOJI_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过罗吉密探网" % FLAG_LUOJI_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发: %s ═══" % EVENT_LUOJI)
	PlayerState.set_flag(FLAG_LUOJI_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LUOJI_TRIGGERED)
	# 设置持久标记：每旬酷吏检查激活
	PlayerState.set_flag(FLAG_LUOJI_ACTIVE, true)
	Logging.info("[PlotController] 持久标记 %s 已激活" % FLAG_LUOJI_ACTIVE)
	EventBus.push_event.emit(EVENT_LUOJI, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LUOJI)


func _check_liyong_trigger() -> void:
	Logging.info("[PlotController] _check_liyong_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, LIYONG_XUN_MIN, LIYONG_XUN_MAX])
	if _xun_count < LIYONG_XUN_MIN:
		return
	if _xun_count > LIYONG_XUN_MAX:
		return
	if PlayerState.has_flag(FLAG_LIYONG_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过李邕之死" % FLAG_LIYONG_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发: %s ═══" % EVENT_LIYONG)
	PlayerState.set_flag(FLAG_LIYONG_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_LIYONG_TRIGGERED)
	EventBus.push_event.emit(EVENT_LIYONG, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LIYONG)


func _check_wangzhongsi_trigger() -> void:
	Logging.info("[PlotController] _check_wangzhongsi_trigger: xun_count=%d, window=[%d,%d]" % [_xun_count, WANGZHONGSI_XUN_MIN, WANGZHONGSI_XUN_MAX])
	if _xun_count < WANGZHONGSI_XUN_MIN:
		return
	if _xun_count > WANGZHONGSI_XUN_MAX:
		return
	if PlayerState.has_flag(FLAG_WANGZHONGSI_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过王忠嗣罢黜" % FLAG_WANGZHONGSI_TRIGGERED)
		return

	Logging.info("[PlotController] ═══ 触发: %s ═══" % EVENT_WANGZHONGSI)
	PlayerState.set_flag(FLAG_WANGZHONGSI_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_WANGZHONGSI_TRIGGERED)
	EventBus.push_event.emit(EVENT_WANGZHONGSI, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_WANGZHONGSI)


# ════════════════════════════════════════════════════════════════
# 🆕 罗吉密探网：每旬酷吏找上门检查
# ════════════════════════════════════════════════════════════════

func _check_luoji_penalty() -> void:
	if not PlayerState.has_flag(FLAG_LUOJI_ACTIVE):
		Logging.info("[PlotController] _check_luoji_penalty: flag_luoji_active 未设置，跳过")
		return

	var roll: int = randi() % 100
	Logging.info("[PlotController] _check_luoji_penalty: roll=%d, threshold=%d%%" % [roll, LUOJI_PENALTY_PCT])
	if roll >= LUOJI_PENALTY_PCT:
		Logging.info("[PlotController] _check_luoji_penalty: roll=%d >= %d，未触发" % [roll, LUOJI_PENALTY_PCT])
		return

	var inspiration: int = PlayerState.get_stat_val("inspiration")
	Logging.info("[PlotController] _check_luoji_penalty: 触发30%概率! inspiration=%d, threshold=%d" % [inspiration, LUOJI_INSPIRATION_THRESHOLD])
	if inspiration <= LUOJI_INSPIRATION_THRESHOLD:
		Logging.info("[PlotController] _check_luoji_penalty: inspiration=%d <= %d，不够高，酷吏没有兴趣" % [inspiration, LUOJI_INSPIRATION_THRESHOLD])
		return

	Logging.info("[PlotController] ═══ 酷吏找上门! push: %s ═══" % EVENT_LUOJI_PENALTY)
	EventBus.push_event.emit(EVENT_LUOJI_PENALTY, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % EVENT_LUOJI_PENALTY)
