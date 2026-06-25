class_name PoemCraftingCalculator extends Node

## 管道乘数矩阵
const CHANNEL_MATRIX = {
    "SECULAR": {
        1: {"history_mult": 0.0, "secular_mult": 1.5},
        2: {"history_mult": 1.0, "secular_mult": 3.0},
        3: {"history_mult": 1.0, "secular_mult": 0.0}
    },
    "BROADCAST": {
        1: {"history_mult": 0.0, "secular_mult": 0.0},
        2: {"history_mult": 1.2, "secular_mult": 0.0},
        3: {"history_mult": 1.5, "secular_mult": 0.0}
    }
}

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
static func calculate_poem_grade(concepts: Array[ImaginaryTag], poem_type: int = -1) -> ChoiceResult:
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

	# 5. 配方路由：基础数值计算
	var base_history := 0.0
	var base_secular := 0.0

	match min_tier:
		1:  # 台阁体：世俗SSS，千古0
			base_secular = total_level * 10.0
		2:  # 诗史：千古SS，世俗负数
			base_history = total_level * 15.0
			base_secular = total_level * (-20.0)
		3:  # 绝唱：千古SSS，世俗0
			base_history = total_level * 20.0

	# 6. 管道乘数叠加（poem_type == -1 时跳过，向后兼容）
	if poem_type != -1:
		var channel_group = ENUMS.get_poem_type_channel(poem_type)
		var multipliers = CHANNEL_MATRIX[channel_group][min_tier]
		base_history *= multipliers["history_mult"]
		base_secular *= multipliers["secular_mult"]

		# 动态 Trait 标签覆盖
		if channel_group == "BROADCAST" and min_tier == 1:
			result.operators.append(
				OperatorFactory.create_trait_operator("[无病呻吟的废纸]")
			)
		elif channel_group == "SECULAR" and min_tier == 2:
			result.operators.append(
				OperatorFactory.create_trait_operator("[触怒龙颜的死书]")
			)

	# 7. 算子生成
	if base_secular != 0:
		result.operators.append(OperatorFactory.create_property_operator("money", base_secular))
	if base_history != 0:
		result.operators.append(OperatorFactory.create_property_operator("literary_fame", base_history))

	# 8. Tier 2 特有副作用（flag 递增 + 政治审查事件推送）
	if min_tier == 2:
		PlayerState.append_flag("flag_poem_tier2_count", 1)
		result.operators.append(OperatorFactory.create_push_event_operator("political_purge_poem"))

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
