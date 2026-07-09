@tool
class_name AdvancePlotPlaceholderOperator extends BaseOperator

## 普通拜谒 — 随机 RELATION_TARGET 关系层级升级一级。


func operate():
	Logging.info("[AdvancePlotPlaceholderOperator] operate: 随机 RELATION_TARGET 关系层级升级")

	# 收集所有 RELATION_TARGET
	var targets: Array[String] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		targets.append(ENUMS.to_relation_str(target_enum_value))
	Logging.info("[AdvancePlotPlaceholderOperator] 候选目标数: %d" % targets.size())

	if targets.is_empty():
		Logging.err("[AdvancePlotPlaceholderOperator] RELATION_TARGET 为空，操作中止")
		return

	# 随机选一个
	var target_tag: String = targets[randi() % targets.size()]
	Logging.info("[AdvancePlotPlaceholderOperator] 随机选中目标: %s" % target_tag)

	# 关系层级升级一级
	var upgraded = RelationFlagManager.upgrade_person_state(target_tag)
	if upgraded:
		show_hint("与%s攀谈甚欢，关系增进" % target_tag)
	else:
		show_hint("与%s攀谈甚欢" % target_tag)


func describe_preview() -> String:
	return "随机与一位人物增进交情，关系层级提升"
