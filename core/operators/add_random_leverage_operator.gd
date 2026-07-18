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
var LEVERAGE_KEY_LABELS: Dictionary = {
	"debt_secret":      tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_D1A59CEE54"),
	"family_scandal":   tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_7D65F67B10"),
	"past_crime":       tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_F66EF53384"),
	"illicit_affair":   tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_254E9A0624"),
	"tax_evasion":      tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_B3AD279BCF"),
	"forgery":          tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_502DC14B76"),
	"bribery_record":   tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_184F5B7573"),
	"academic_fraud":   tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_B13ABA59F6"),
	"embezzlement":     tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_7F26389725"),
	"betrayal_secret":  tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_3996EDABB3"),
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
	show_hint(tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_C58E3CFC02") % [chosen_target, label])


func describe_preview() -> String:
	if not target_key.is_empty():
		return tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_EC0F4AD515") % target_key
	return tr("CODE_ADD_RANDOM_LEVERAGE_OPERATOR_0108716880")
