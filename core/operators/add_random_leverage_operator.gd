@tool
class_name AddRandomLeverageOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# AddRandomLeverageOperator — 给 target 加把柄
#
# DSL 语法:
#   add_random_leverage()
#   add_random_leverage(target_key=npc_target)
#
# target_key 可选 — 从 context 读取 target_tag。
# 不传 target_key 则从所有 RELATION_TARGET 随机选一个。
#
# 把柄 key 池为通用无状态叙事标签，不绑定任何 NPC 状态。
# ═══════════════════════════════════════════════════════════

## 通用把柄 key 池 — 纯叙事标签，不绑定 NPC 状态
const LEVERAGE_KEY_POOL: Array[String] = [
	"debt_secret",
	"family_scandal",
	"past_crime",
	"illicit_affair",
	"tax_evasion",
	"forgery",
	"bribery_record",
	"academic_fraud",
	"embezzlement",
	"betrayal_secret",
]

## key → 中文描述映射（用于 hint 展示）
const LEVERAGE_KEY_LABELS: Dictionary = {
	"debt_secret":      "隐匿的巨额债务",
	"family_scandal":   "见不得光的家丑",
	"past_crime":       "尘封的旧日罪行",
	"illicit_affair":   "与人私通的证据",
	"tax_evasion":      "常年逃税的账目",
	"forgery":          "伪造文书的笔迹",
	"bribery_record":   "收受贿赂的记录",
	"academic_fraud":   "科举舞弊的线索",
	"embezzlement":     "挪用公款的痕迹",
	"betrayal_secret":  "背信弃义的密约",
}

## 可选 — 从 context 读取 target_tag 的 key。空字符串 = 随机选。
@export var target_key: String = ""

## init 阶段捕获的 context
var _captured_context: Dictionary = {}


func init(_context: Dictionary) -> Dictionary:
	_captured_context = _context.duplicate()
	return _context


func operate():
	Logging.info("[AddRandomLeverageOperator] operate: 开始选取目标")

	var chosen_target: String = ""

	# 优先从 context 读取指定 target
	if not target_key.is_empty():
		chosen_target = _captured_context.get(target_key, "")
		if not chosen_target.is_empty():
			Logging.info("[AddRandomLeverageOperator] 从 context[%s] 读取 target=%s" % [target_key, chosen_target])

	# 回退：随机选
	if chosen_target.is_empty():
		var candidates: Array[String] = []
		for target_enum_value in ENUMS.RELATION_TARGET.values():
			var target_tag := ENUMS.to_relation_str(target_enum_value)
			candidates.append(target_tag)

		if candidates.is_empty():
			Logging.err("[AddRandomLeverageOperator] RELATION_TARGET 为空，操作中止")
			return

		chosen_target = candidates[randi() % candidates.size()]
		Logging.info("[AddRandomLeverageOperator] 随机选中 target=%s" % chosen_target)

	# 3. 随机选一个把柄 key
	var chosen_key: String = LEVERAGE_KEY_POOL[randi() % LEVERAGE_KEY_POOL.size()]
	Logging.info("[AddRandomLeverageOperator] 随机选中 key=%s" % chosen_key)

	# 4. 添加把柄
	RelationFlagManager.add_leverage(chosen_target, chosen_key)

	# 5. hint
	var label = LEVERAGE_KEY_LABELS.get(chosen_key, chosen_key)
	show_hint("探得了「%s」的把柄：%s" % [chosen_target, label])


func describe_preview() -> String:
	if not target_key.is_empty():
		return "添加把柄给 context[%s]" % target_key
	return "在暗巷中打探消息，或可获知他人把柄"
