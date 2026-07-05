class_name PoemCraftingCalculator extends Node

## 诗词评价引擎 V7 — 纯精确 Set 匹配 imaginary uuid + 管道乘数
##
## V7 变更: 输入 Imaginary 数组而非 ImaginaryConcept。Tier/Level 已删除。
## 收益公式固定: base_secular=20, base_history=40，经管道乘数调整。

## 收益基数常量（原 Level 写死逻辑，V7 简化为固定值）
const BASE_SECULAR := 20.0
const BASE_HISTORY := 40.0

## 管道乘数矩阵
const CHANNEL_MATRIX = {
	"SECULAR": {"history_mult": 1.0, "secular_mult": 1.5},
	"BROADCAST": {"history_mult": 1.2, "secular_mult": 0.0}
}

const PENALTY_TEXT := "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。"


## 诗词创作结果
class PoemCraftingResult:
	var passed: bool = false
	var fail_reason: String = ""           ## "no_match" | ""
	var penalty_text: String = ""          ## 失败提示文案
	var operators: Array = []              ## 通过时的收益算子列表
	var secular_value: float = 0.0
	var literary_value: float = 0.0
	var matched_recipe: Poem = null        ## 匹配到的食谱（通过时非 null）


## 主入口：诗词评价引擎 V7
## imaginaries: 选中的 Imaginary 数组（必须 3 个）
## recipe_index: Database.recipe_index — {sorted_key → Poem recipe}
static func calculate_poem_grade(imaginaries: Array, recipe_index: Dictionary) -> PoemCraftingResult:
	var result = PoemCraftingResult.new()

	if imaginaries.size() != 3:
		result.passed = false
		result.fail_reason = "imaginary_count"
		result.penalty_text = PENALTY_TEXT
		Logging.warn("PoemCraftingCalculator: 需要恰好 3 个 Imaginary，实际 %d" % imaginaries.size())
		return result

	# ── 构建 imaginary uuid 集合 ──
	var uuids: Array[String] = []
	for imag in imaginaries:
		if imag is Imaginary:
			uuids.append(imag.uuid.to_lower())

	var lookup_key = FragmentMatcher.build_key(uuids)
	Logging.info("PoemCraftingCalculator: lookup_key=%s, recipe_index_size=%d" % [lookup_key, recipe_index.size()])

	# ── 精确 Set 匹配 ──
	if recipe_index.has(lookup_key):
		result.matched_recipe = recipe_index[lookup_key]
		Logging.info("PoemCraftingCalculator: 精确匹配食谱 %s" % result.matched_recipe.name)
	else:
		Logging.info("PoemCraftingCalculator: 无匹配")
		result.passed = false
		result.fail_reason = "no_match"
		result.penalty_text = PENALTY_TEXT
		return result

	# ── 收益公式（固定值 + 管道乘数）──
	var base_history := BASE_HISTORY
	var base_secular := BASE_SECULAR

	var recipe = result.matched_recipe
	if recipe and not recipe.specific_topic.is_empty():
		var poem_type = ENUMS.POEM_TYPE.get(recipe.specific_topic)
		if poem_type != null:
			var channel_group = ENUMS.get_poem_type_channel(poem_type)
			var multipliers = CHANNEL_MATRIX.get(channel_group, {"history_mult": 1.0, "secular_mult": 1.0})
			base_history *= multipliers["history_mult"]
			base_secular *= multipliers["secular_mult"]
			Logging.info("PoemCraftingCalculator: channel=%s, multipliers=%s" % [channel_group, multipliers])

	result.secular_value = base_secular
	result.literary_value = base_history

	# ── 算子生成 ──
	if base_secular != 0:
		result.operators.append(OperatorFactory.create_property_operator("money", base_secular))
	if base_history != 0:
		result.operators.append(OperatorFactory.create_property_operator("literary_fame", base_history))

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
