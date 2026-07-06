@tool
class_name ConsumeRandomLeverageOperator extends BaseOperator

## 消耗随机一个把柄（从所有 RELATION_TARGET 中随机选）。
## 金钱/惩罚等收益由 archetype DSL 控制，此 operator 仅负责把柄消耗。
## 若无任何把柄，打 err 并静默返回。


## 🆕 静态可行性检查：当前是否有任何可用把柄。
## 用于 sub-action picker 构建阶段决定隐藏/显示。
static func is_viable() -> bool:
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		if RelationFlagManager.has_leverage(target_tag):
			Logging.info("[ConsumeRandomLeverageOperator] is_viable: 发现把柄在 target='%s'" % target_tag)
			return true
	Logging.info("[ConsumeRandomLeverageOperator] is_viable: 没有任何把柄可用")
	return false


func operate():
	Logging.info("[ConsumeRandomLeverageOperator] operate: 开始收集所有可用把柄")

	# 1. 收集所有有把柄的目标
	var candidates: Array[Dictionary] = []
	for target_enum_value in ENUMS.RELATION_TARGET.values():
		var target_tag := ENUMS.to_relation_str(target_enum_value)
		var keys: Array = RelationFlagManager.get_leverage_keys(target_tag)
		if not keys.is_empty():
			candidates.append({"target_tag": target_tag, "keys": keys})
			Logging.info("[ConsumeRandomLeverageOperator] 发现目标 %s，持有 %d 个把柄: %s" % [target_tag, keys.size(), str(keys)])

	if candidates.is_empty():
		Logging.err("[ConsumeRandomLeverageOperator] 没有任何把柄可用，操作中止")
		return

	# 2. 随机选一个目标
	var chosen: Dictionary = candidates[randi() % candidates.size()]
	var target_tag: String = chosen["target_tag"]
	var keys: Array = chosen["keys"]
	var leverage_key: String = keys.back()  # LIFO: 取最近获得的把柄

	Logging.info("[ConsumeRandomLeverageOperator] 随机选中目标=%s, 消耗把柄='%s'" % [target_tag, leverage_key])

	# 3. 消费把柄（金钱由 archetype DSL prop_add 控制）
	var consumed: bool = RelationFlagManager.consume_leverage(target_tag, leverage_key)
	if not consumed:
		Logging.err("[ConsumeRandomLeverageOperator] consume_leverage 失败: target=%s, key=%s" % [target_tag, leverage_key])
		return

	Logging.info("[ConsumeRandomLeverageOperator] 把柄已消耗: target=%s, key=%s" % [target_tag, leverage_key])


func describe_preview() -> String:
	return "消耗随机一个把柄"
