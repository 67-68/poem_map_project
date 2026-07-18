@tool
class_name AddRandomIntroOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# AddRandomIntroOperator — 给 target 加引荐信
#
# DSL 语法:
#   add_random_intro()
#   add_random_intro(target_key=npc_target)
#
# target_key 可选 — 从 context 读取 target_tag。
# 不传 target_key 则从所有 RELATION_TARGET 随机选一个。
#
# intro_key 使用简单的标准化 key（格式: "intro_from_{target_tag}"），
# 后续可通过 consume_intro(target_tag, key) 消费。
# ═══════════════════════════════════════════════════════════

## 可选 — 从 context 读取 target_tag 的 key。空字符串 = 随机选。
@export var target_key: String = ""

## init 阶段捕获的 context
var _captured_context: Dictionary = {}


func init(_context: Dictionary) -> Dictionary:
	_captured_context = _context.duplicate()
	return _context


func operate():
	Logging.info("[AddRandomIntroOperator] operate: 开始选取目标")

	var chosen_target: String = ""

	# 优先从 context 读取指定 target
	if not target_key.is_empty():
		chosen_target = _captured_context.get(target_key, "")
		if not chosen_target.is_empty():
			Logging.info("[AddRandomIntroOperator] 从 context[%s] 读取 target=%s" % [target_key, chosen_target])

	# 回退：随机选
	if chosen_target.is_empty():
		var candidates: Array[String] = []
		for target_enum_value in ENUMS.RELATION_TARGET.values():
			var target_tag := ENUMS.to_relation_str(target_enum_value)
			candidates.append(target_tag)

		if candidates.is_empty():
			Logging.err("[AddRandomIntroOperator] RELATION_TARGET 为空，操作中止")
			return

		chosen_target = candidates[randi() % candidates.size()]
		Logging.info("[AddRandomIntroOperator] 随机选中 target=%s" % chosen_target)

	# 2. 生成 intro_key
	var intro_key: String = "intro_from_" + chosen_target
	Logging.info("[AddRandomIntroOperator] intro_key=%s" % intro_key)

	# 3. 添加引荐信
	RelationFlagManager.add_intro(chosen_target, intro_key)

	# 4. hint
	show_hint(tr("CODE_ADD_RANDOM_INTRO_OPERATOR_6C288E2BB4") % chosen_target)


func describe_preview() -> String:
	if not target_key.is_empty():
		return tr("CODE_ADD_RANDOM_INTRO_OPERATOR_7C0C7B5038") % target_key
	return tr("CODE_ADD_RANDOM_INTRO_OPERATOR_D093C7C50C")
