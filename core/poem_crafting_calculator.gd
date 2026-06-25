class_name PoemCraftingCalculator extends Node


## IAM 判定（复用 TierDeterminer 中的 IAM 检测模式）
static func _get_current_iam() -> String:
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_KUANGKE):
		return "kuangke"
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_ZUANYING):
		return "zuanying"
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_FENGYING):
		return "fengying"
	return ""


## 健康消耗
static func _calculate_health_cost(concepts: Array[ImaginaryTag]) -> float:
	var level_factor = 0.5 if _has_high_level(concepts) else 0.2
	var base_health = 0.0
	for c in concepts:
		base_health += c.current_level * level_factor
	return base_health


static func _has_high_level(concepts: Array[ImaginaryTag]) -> bool:
	for c in concepts:
		if c.current_level == 2:
			return true
	return false


## 主入口：诗词评价引擎
## 返回 ChoiceResult，其 operators 数组包含所有结算算子
static func calculate_poem_grade(concepts: Array[ImaginaryTag]) -> ChoiceResult:
	var result = ChoiceResult.new()

	# 1. 木桶效应：最低 tier 决定配方
	var min_tier = 999
	var total_level = 0
	for c in concepts:
		if c.current_tier > 0:
			min_tier = mini(min_tier, c.current_tier)
		total_level += c.current_level

	if min_tier == 999:
		min_tier = 1  # 兜底

	# 2. 当前 IAM
	var current_iam = _get_current_iam()

	# 3. 虚伪反噬：IAM=zuanying 且最低 tier=3 → 千古归零，世俗打折
	if current_iam == "zuanying" and min_tier == 3:
		result.operators.append(
			OperatorFactory.create_trait_operator("[虚伪的拼凑者]")
		)
		return result

	# 4. 健康消耗（所有配方共用）
	var health_cost = _calculate_health_cost(concepts)
	if health_cost > 0:
		result.operators.append(
			OperatorFactory.create_property_operator("health", -health_cost)
		)

	# 5. 配方路由
	match min_tier:
		1:  # 台阁体：世俗SSS，千古0
			var secular_val = total_level * 10
			result.operators.append(OperatorFactory.create_property_operator("money", secular_val))

		2:  # 诗史：千古SS，世俗负数
			var history_val = total_level * 15
			var secular_val = total_level * (-20)
			result.operators.append(OperatorFactory.create_property_operator("literary_fame", history_val))
			result.operators.append(OperatorFactory.create_property_operator("money", secular_val))
			# 🆕 递增诗史计数 → 触发政治审查
			PlayerState.append_flag("flag_poem_tier2_count", 1)
			result.operators.append(OperatorFactory.create_push_event_operator("political_purge_poem"))

		3:  # 绝唱：千古SSS，世俗0
			var history_val = total_level * 20
			result.operators.append(OperatorFactory.create_property_operator("literary_fame", history_val))

	return result


## 翻译 operators 为人类可读的预览文本（供 PoemCrafter UI tooltip 展示）
static func translate(ops: Array[BaseOperator]) -> String:
	var lines: Array[String] = []
	for op in ops:
		if not op:
			continue
		var text = op.describe_preview()
		if not text.is_empty():
			lines.append(text)
	return "\n".join(lines)
