class_name PoemCraftingCalculator extends Node

## 诗词评价引擎 V4 — 双层校验 (Tier + FragmentMatcher) + 10.4 管道乘数
##
## 第一层: Tier 木桶效应（现有逻辑）
## 第二层: FragmentMatcher 详细概念匹配（新增，需传入 required_fragments）
## 第三层: 10.4 管道乘数矩阵（SECULAR/BROADCAST）

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

const PENALTY_TEXT := "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。"


## 诗词创作结果
class PoemCraftingResult:
	var passed: bool = false           ## 双层校验是否通过
	var fail_reason: String = ""       ## "tier" | "fragment" | ""
	var penalty_text: String = ""      ## 失败时的惩罚文案
	var operators: Array = []          ## 通过时的收益算子列表
	var secular_value: float = 0.0     ## 世俗收益（透传给 Poem trait）
	var literary_value: float = 0.0   ## 文学收益（透传给 Poem trait）
	var poem_level: int = 0            ## 诗词等级 (0-2)
	var min_tier: int = 0              ## 木桶最低 tier


## IAM 判定
static func _get_current_iam() -> String:
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_KUANGKE):
		return "kuangke"
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_ZUANYING):
		return "zuanying"
	if PlayerState.has_trait(ENUMS.TRAITS.KUANGDA_FENGYING):
		return "fengying"
	return ""


## 健康消耗
static func _calculate_health_cost(concepts: Array) -> float:
	var level_factor = 0.5 if _has_high_level(concepts) else 0.2
	var base_health = 0.0
	for c in concepts:
		if c and c is ImaginaryConcept:
			base_health += c.current_level * level_factor
	return base_health


static func _has_high_level(concepts: Array) -> bool:
	for c in concepts:
		if c and c is ImaginaryConcept and c.current_level == 2:
			return true
	return false


## 主入口：诗词评价引擎
## concepts: 选中的 ImaginaryConcept 数组
## poem_type: POEM_TYPE 枚举值（-1 = 跳过管道乘数，向后兼容）
## required_fragments: 四段式 Tag 列表（可选，用于 FragmentMatcher 双层校验）
static func calculate_poem_grade(concepts: Array, poem_type: int = -1, required_fragments: Array = []) -> PoemCraftingResult:
	var result = PoemCraftingResult.new()

	# ── 第一层：Tier 木桶效应 ──
	var min_tier = 999
	var total_level = 0
	for c in concepts:
		if not (c is ImaginaryConcept):
			continue
		if c.current_tier > 0:
			min_tier = mini(min_tier, c.current_tier)
		total_level += c.current_level

	if min_tier == 999:
		min_tier = 1
	result.min_tier = min_tier
	result.poem_level = total_level

	# 虚伪反噬：IAM=zuanying 且最低 tier=3
	var current_iam = _get_current_iam()
	if current_iam == "zuanying" and min_tier == 3:
		result.passed = false
		result.fail_reason = "tier"
		result.penalty_text = "[虚伪的拼凑者]"
		return result

	# ── 第二层：FragmentMatcher（如果提供了 required_fragments）──
	if not required_fragments.is_empty():
		var weight = FragmentMatcher.match_concepts(concepts, required_fragments)
		if weight < FragmentMatcher.THRESHOLD:
			result.passed = false
			result.fail_reason = "fragment"
			result.penalty_text = PENALTY_TEXT
			Logging.info("PoemCraftingCalculator: FragmentMatcher 未通过 (weight=%d < %d)" % [weight, FragmentMatcher.THRESHOLD])
			return result
		Logging.info("PoemCraftingCalculator: FragmentMatcher 通过 (weight=%d)" % weight)

	# ── 健康消耗 ──
	var health_cost = _calculate_health_cost(concepts)
	if health_cost > 0:
		result.operators.append(
			OperatorFactory.create_property_operator("health", -health_cost)
		)

	# ── 第三层：配方路由 + 10.4 管道乘数 ──
	var base_history := 0.0
	var base_secular := 0.0

	match min_tier:
		1:
			base_secular = total_level * 10.0
		2:
			base_history = total_level * 15.0
			base_secular = total_level * (-20.0)
		3:
			base_history = total_level * 20.0

	# 管道乘数叠加
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

	# ── 存储收益值 ──
	result.secular_value = base_secular
	result.literary_value = base_history

	# ── 算子生成 ──
	if base_secular != 0:
		result.operators.append(OperatorFactory.create_property_operator("money", base_secular))
	if base_history != 0:
		result.operators.append(OperatorFactory.create_property_operator("literary_fame", base_history))

	# Tier 2 特有副作用
	if min_tier == 2:
		PlayerState.append_flag("flag_poem_tier2_count", 1)
		result.operators.append(OperatorFactory.create_push_event_operator("political_purge_poem"))

	result.passed = true
	return result


## 翻译 operators 为人类可读的预览文本
static func translate(ops: Array) -> String:
	var lines: Array[String] = []
	for op in ops:
		if not op:
			continue
		var text = op.describe_preview()
		if not text.is_empty():
			lines.append(text)
	return "\n".join(lines)


## 向后兼容：旧接口返回 ChoiceResult
static func calculate_poem_grade_legacy(concepts: Array, poem_type: int = -1) -> ChoiceResult:
	var result = calculate_poem_grade(concepts, poem_type)
	if not result.passed:
		var cr = ChoiceResult.new()
		return cr
	var cr = ChoiceResult.new()
	cr.operators = result.operators
	return cr
