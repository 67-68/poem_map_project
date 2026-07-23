@tool
class_name ExamEndingRouter extends RefCounted
## 大考结局优先级路由器
## 静态类，按优先级评估玩家属性 → 推入对应的 DeathEvent

const FLAG_TRIGGERED: String = "flag_exam_ending_routed"

## 结局事件 UUID 映射
const ENDING_HIDDEN: String = "event_ending_hidden"
const ENDING_GOOD_MOMENTUM: String = "event_ending_good_momentum"
const ENDING_MEDIUM_PRESTIGE: String = "event_ending_medium_prestige"
const ENDING_BAD_INSPIRATION: String = "event_ending_bad_inspiration"
const ENDING_RICH: String = "event_ending_rich"
const ENDING_DEFAULT: String = "event_ending_default"

## 阈值常量
const THRESHOLD_PRESTIGE: int = 90
const THRESHOLD_MOMENTUM: int = 9
const THRESHOLD_INSPIRATION: int = 100
const THRESHOLD_MONEY: int = 1000
const THRESHOLD_LOW: int = 50


## 检查 created_poems 中是否存在 level == 3 的诗词
static func has_level_3_poem() -> bool:
	if not PlayerState:
		Logging.err("[ExamEndingRouter] has_level_3_poem: PlayerState 不可用")
		return false

	for entry in PlayerState.created_poems:
		if entry is Poem and entry.level == 3:
			Logging.info("[ExamEndingRouter] has_level_3_poem: 发现 level=3 诗词 '%s'" % entry.name)
			return true

	Logging.info("[ExamEndingRouter] has_level_3_poem: 未找到 level=3 诗词")
	return false


## 读取属性当前值
static func _get_stat(prop_key: String) -> int:
	if not PlayerState:
		Logging.err("[ExamEndingRouter] _get_stat: PlayerState 不可用, prop_key='%s'" % prop_key)
		return 0
	return PlayerState.get_stat_val(prop_key)


## 优先级匹配 → 推入对应结局 DeathEvent
static func evaluate() -> void:
	Logging.info("[ExamEndingRouter] ═══ evaluate: 开始大考结局路由 ═══")

	# 防重复：同一次游戏只路由一次
	if PlayerState.has_flag(FLAG_TRIGGERED):
		Logging.info("[ExamEndingRouter] evaluate: flag '%s' 已存在，跳过重复路由" % FLAG_TRIGGERED)
		return

	var prestige: int = _get_stat("prestige")
	var momentum: int = _get_stat("momentum")
	var inspiration: int = _get_stat("inspiration")
	var money: int = _get_stat("money")

	Logging.info("[ExamEndingRouter] evaluate: 望=%d, 势=%d, 兴=%d, 钱=%d" % [prestige, momentum, inspiration, money])

	var matched_event: String = ""

	# 优先级 1: 望 ≥ 100 且有 level 3 诗词 → hidden
	if prestige >= THRESHOLD_PRESTIGE and has_level_3_poem():
		matched_event = ENDING_HIDDEN
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → hidden (望≥100 + Lv3诗词)")

	# 优先级 2: 势 ≥ 100 → good
	elif momentum >= THRESHOLD_MOMENTUM:
		matched_event = ENDING_GOOD_MOMENTUM
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → good (势≥100)")

	# 优先级 3: 望 ≥ 100 → medium
	elif prestige >= THRESHOLD_PRESTIGE:
		matched_event = ENDING_MEDIUM_PRESTIGE
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → medium (望≥100)")

	# 优先级 4: 兴 ≥ 100 → bad
	elif inspiration >= THRESHOLD_INSPIRATION:
		matched_event = ENDING_BAD_INSPIRATION
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → bad (兴≥100)")

	# 优先级 5: 钱 ≥ 1000 且 势望兴均 < 50 → rich
	elif money >= THRESHOLD_MONEY and momentum < THRESHOLD_LOW and prestige < THRESHOLD_LOW and inspiration < THRESHOLD_LOW:
		matched_event = ENDING_RICH
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → rich (钱≥1000 + 势望兴<50)")

	# 优先级 6: fallback → default
	else:
		matched_event = ENDING_DEFAULT
		Logging.info("[ExamEndingRouter] evaluate: 匹配 → default (fallback)")

	# 设置防重复标记
	PlayerState.set_flag(FLAG_TRIGGERED, true)
	Logging.info("[ExamEndingRouter] evaluate: flag '%s' 已设置" % FLAG_TRIGGERED)

	# 推入结局事件
	Logging.info("[ExamEndingRouter] evaluate: 推入结局事件 '%s'" % matched_event)
	EventBus.request_event_key.emit(matched_event, {})
