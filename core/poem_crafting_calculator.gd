class_name PoemCraftingCalculator extends Node

## 诗词评价引擎 V6 — 精确 Set 匹配 + Tier 木桶效应 + 无 Level
##
## Layer 1: FragmentMatcher 精确集合匹配（两段式 concept uuid）
## Layer 2: Tier 木桶效应（Tier 1/2）
## 管道乘数：自动从匹配食谱的 specific_topic 获取
##
## V6 变更: level 系统已删除，收益公式中的 level 因子写死为 2

## Level 写死常量（原为 max(3个concept的current_level)，现已删除 level 系统）
const LEVEL_OVERRIDE := 2

## 管道乘数矩阵
const CHANNEL_MATRIX = {
	"SECULAR": {
		1: {"history_mult": 0.0, "secular_mult": 1.5},
		2: {"history_mult": 1.0, "secular_mult": 3.0}
	},
	"BROADCAST": {
		1: {"history_mult": 0.0, "secular_mult": 0.0},
		2: {"history_mult": 1.2, "secular_mult": 0.0}
	}
}

const PENALTY_TEXT := "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。"
const DOGGEREL_TEXT := "意象未全，凑成一首打油诗，聊以自慰。"
const DOGGEREL_LITERARY := 5.0  ## 打油诗 literary_fame 固定增益


## 诗词创作结果
class PoemCraftingResult:
	var passed: bool = false           ## 是否通过（精确匹配 + Tier 校验）
	var is_doggerel: bool = false      ## 是否为打油诗（2/3 子集命中）
	var fail_reason: String = ""       ## "no_match" | "doggerel" | ""
	var penalty_text: String = ""      ## 失败/打油诗的提示文案
	var operators: Array = []          ## 通过/打油诗时的收益算子列表
	var secular_value: float = 0.0     ## 世俗收益
	var literary_value: float = 0.0    ## 文学收益
	var min_tier: int = 1              ## 木桶最低 tier (1 或 2)
	var matched_recipe: Poem = null    ## 匹配到的食谱（精确匹配时非 null）


## 主入口：诗词评价引擎 V6
## concepts: 选中的 ImaginaryConcept 数组（必须 3 个）
## recipe_index: Database.recipe_index — {sorted_key → Poem recipe}
static func calculate_poem_grade(concepts: Array, recipe_index: Dictionary) -> PoemCraftingResult:
	var result = PoemCraftingResult.new()

	if concepts.size() != 3:
		result.passed = false
		result.fail_reason = "concept_count"
		result.penalty_text = PENALTY_TEXT
		Logging.warn("PoemCraftingCalculator: 需要恰好 3 个 concept，实际 %d" % concepts.size())
		return result

	# ── 构建 concept 集合（两段式 uuid 直接作为完整字符串）──
	var concept_uuids: Array[String] = []
	for c in concepts:
		if c is ImaginaryConcept:
			concept_uuids.append(c.uuid.to_lower())

	# 排序后拼接为索引 key
	var sorted_uuids = concept_uuids.duplicate()
	sorted_uuids.sort()
	var lookup_key = "|".join(sorted_uuids)

	Logging.info("PoemCraftingCalculator: lookup_key=%s, recipe_index_size=%d" % [lookup_key, recipe_index.size()])

	# ── Layer 1: 精确 Set 匹配 ──
	if recipe_index.has(lookup_key):
		result.matched_recipe = recipe_index[lookup_key]
		Logging.info("PoemCraftingCalculator: 精确匹配食谱 %s" % result.matched_recipe.name)
	else:
		# ── 2/3 子集检测 ──
		var doggerel_recipe: Poem = _find_2of3_match(concept_uuids, recipe_index)
		if doggerel_recipe:
			Logging.info("PoemCraftingCalculator: 2/3 子集匹配 → 打油诗 (recipe=%s)" % doggerel_recipe.name)
			result.is_doggerel = true
			result.passed = true
			result.fail_reason = "doggerel"
			result.penalty_text = DOGGEREL_TEXT
			result.literary_value = DOGGEREL_LITERARY
			result.operators.append(
				OperatorFactory.create_property_operator("literary_fame", DOGGEREL_LITERARY)
			)
			return result
		else:
			Logging.info("PoemCraftingCalculator: 无匹配 — <2 概念命中任何食谱")
			result.passed = false
			result.fail_reason = "no_match"
			result.penalty_text = PENALTY_TEXT
			return result

	# ── Layer 2: Tier 木桶效应 + 收益计算 ──
	var min_tier = 999
	for c in concepts:
		if not (c is ImaginaryConcept):
			continue
		if c.current_tier > 0:
			min_tier = mini(min_tier, c.current_tier)

	if min_tier >= 2:
		min_tier = 2

	if min_tier == 999:
		min_tier = 1
	result.min_tier = min_tier

	Logging.info("PoemCraftingCalculator: min_tier=%d, level=OVERRIDE(%d)" % [min_tier, LEVEL_OVERRIDE])

	# ── 收益公式（level 写死）──
	var base_history := 0.0
	var base_secular := 0.0

	match min_tier:
		1:
			base_secular = LEVEL_OVERRIDE * 10.0
		2:
			base_history = LEVEL_OVERRIDE * 20.0
			base_secular = LEVEL_OVERRIDE * (-20.0)

	# ── 管道乘数（从匹配食谱的 specific_topic 获取）──
	var recipe = result.matched_recipe
	if recipe and not recipe.specific_topic.is_empty():
		var poem_type = ENUMS.POEM_TYPE.get(recipe.specific_topic)
		if poem_type != null:
			var channel_group = ENUMS.get_poem_type_channel(poem_type)
			var multipliers = CHANNEL_MATRIX[channel_group].get(min_tier, {"history_mult": 1.0, "secular_mult": 1.0})
			base_history *= multipliers["history_mult"]
			base_secular *= multipliers["secular_mult"]
			Logging.info("PoemCraftingCalculator: channel=%s, tier=%d, multipliers=%s" % [channel_group, min_tier, multipliers])

	# ── 存储收益值 ──
	result.secular_value = base_secular
	result.literary_value = base_history

	# ── 算子生成 ──
	if base_secular != 0:
		result.operators.append(OperatorFactory.create_property_operator("money", base_secular))
	if base_history != 0:
		result.operators.append(OperatorFactory.create_property_operator("literary_fame", base_history))

	result.passed = true
	return result


## 在所有食谱中查找是否有恰好 2 个 concept 命中的食谱
## 返回第一个匹配的食谱，无匹配则返回 null
static func _find_2of3_match(concept_uuids: Array[String], recipe_index: Dictionary) -> Poem:
	var concept_set: Dictionary = {}
	for uuid in concept_uuids:
		concept_set[uuid] = true

	for recipe_key in recipe_index:
		var recipe: Poem = recipe_index[recipe_key]
		if not recipe or recipe.required_fragments.is_empty():
			continue

		var match_count := 0
		for req_frag in recipe.required_fragments:
			if concept_set.has(req_frag.to_lower()):
				match_count += 1
			if match_count >= 2:
				return recipe

	return null


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


## 向后兼容：旧接口返回 ChoiceResult（保留用于过渡）
static func calculate_poem_grade_legacy(concepts: Array, poem_type: int = -1) -> ChoiceResult:
	var result = calculate_poem_grade(concepts, {})
	if not result.passed:
		var cr = ChoiceResult.new()
		return cr
	var cr = ChoiceResult.new()
	cr.operators = result.operators
	return cr
