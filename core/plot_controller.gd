extends Node
## PlotController — Autoload，根据 event_counter + xun_tick 推动主线剧情
##
## 职责：
##   1. 监听 TimeService.on_xun_tick，累计 xun 次数
##   2. 在第 3 旬时，检查 event_counter == 2，触发同乡来访事件
##   3. 通过 flag_bool 持久化防重复触发

# ════════════════════════════════════════════════════════════════
# 常量
# ════════════════════════════════════════════════════════════════

const TRIGGER_XUN: int = 3
const REQUIRED_EVENT_COUNT: int = 2
const PLOT_EVENT_KEY: String = "plot_prompt_user_action"
const FLAG_TRIGGERED: String = "plot_prompt_user_action_triggered"

# ════════════════════════════════════════════════════════════════
# 内部状态
# ════════════════════════════════════════════════════════════════

var _xun_count: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 监听每旬 tick
	if not TimeService.on_xun_tick.is_connected(_on_xun_tick):
		TimeService.on_xun_tick.connect(_on_xun_tick)
		Logging.info("[PlotController] 已连接 TimeService.on_xun_tick")

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

	# 检查触发条件
	if _xun_count != TRIGGER_XUN:
		Logging.info("[PlotController] xun_count=%d ≠ %d，跳过触发检查" % [_xun_count, TRIGGER_XUN])
		return

	if GameState.event_counter < REQUIRED_EVENT_COUNT:
		Logging.info("[PlotController] event_counter=%d < %d，跳过触发" % [GameState.event_counter, REQUIRED_EVENT_COUNT])
		return

	# 防重复：检查持久化 flag
	if PlayerState.has_flag(FLAG_TRIGGERED):
		Logging.info("[PlotController] flag '%s' 已存在，跳过重复触发" % FLAG_TRIGGERED)
		return

	# 🎯 条件满足，触发同乡来访事件
	Logging.info("[PlotController] ═══ 触发剧情事件: %s ═══" % PLOT_EVENT_KEY)

	# 设置持久化防重复标记
	PlayerState.set_flag(FLAG_TRIGGERED, true)
	Logging.info("[PlotController] flag '%s' 已设置" % FLAG_TRIGGERED)

	# 推入事件栈
	EventBus.push_event.emit(PLOT_EVENT_KEY, {})
	Logging.info("[PlotController] 已发射 push_event: %s" % PLOT_EVENT_KEY)
