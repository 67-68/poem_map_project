@tool
class_name AddRandomIntroOperator extends BaseOperator

# ═══════════════════════════════════════════════════════════
# AddRandomIntroOperator — 赴宴雅集：随机给一个 target 加引荐信
#
# DSL 语法:
#   add_random_intro()
#
# 无参数 — 从所有 RELATION_TARGET 中随机选一个，
# 调用 RelationFlagManager.add_intro()。
#
# intro_key 使用简单的标准化 key（格式: "intro_from_{target_tag}"），
# 后续可通过 consume_intro(target_tag, key) 消费。
# ═══════════════════════════════════════════════════════════


func operate():
	Logging.info("[AddRandomIntroOperator] operate: 开始随机选取目标")
	
	# 1. 收集所有 RELATION_TARGET
	var candidates: Array[String] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		candidates.append(target_tag)
	
	if candidates.is_empty():
		Logging.err("[AddRandomIntroOperator] RELATION_TARGET 为空，操作中止")
		return
	
	# 2. 随机选一个 target
	var chosen_target: String = candidates[randi() % candidates.size()]
	Logging.info("[AddRandomIntroOperator] 随机选中 target=%s" % chosen_target)
	
	# 3. 生成 intro_key
	var intro_key: String = "intro_from_" + chosen_target
	Logging.info("[AddRandomIntroOperator] intro_key=%s" % intro_key)
	
	# 4. 添加引荐信
	RelationFlagManager.add_intro(chosen_target, intro_key)
	
	# 5. hint
	show_hint("宴席间获得了「%s」的引荐信" % chosen_target)


func describe_preview() -> String:
	return "赴宴雅集，或可获得某人的引荐信"
