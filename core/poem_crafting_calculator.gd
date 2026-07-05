class_name PoemCraftingCalculator extends Node

## 诗词评价引擎 V8 — C(N,3) 组合枚举 + mode 覆盖 channel
##
## V8 变更: 移除固定 3 个的限制。传入 N 个 Imaginary，内部枚举所有 3-组合匹配食谱。
## 新增 mode 参数（"deng_gao" / "gan_ye"），覆盖 recipe 的 channel 乘数。

## 收益基数常量
const BASE_SECULAR := 20.0
const BASE_HISTORY := 40.0

## 管道乘数矩阵
const CHANNEL_MATRIX = {
	"SECULAR": {"history_mult": 1.0, "secular_mult": 1.5},
	"BROADCAST": {"history_mult": 1.2, "secular_mult": 0.0}
}

## mode → channel 覆盖映射（按钮直接决定管道）
const MODE_CHANNEL_MAP := {
	"deng_gao": "BROADCAST",  ## 登高抒怀 → 文学价值为主
	"gan_ye": "SECULAR",      ## 干谒权贵 → 世俗价值为主
}

const PENALTY_TEXT := "意象散乱，强行拼凑。你在这堆废纸中枯坐了一夜，一无所获。"


## 诗词创作结果
class PoemCraftingResult:
	var passed: bool = false
	var fail_reason: String = ""           ## "no_match" | "too_few"
	var penalty_text: String = ""          ## 失败提示文案
	var operators: Array = []              ## 通过时的收益算子列表
	var secular_value: float = 0.0
	var literary_value: float = 0.0
	var matched_recipe: Poem = null        ## 匹配到的食谱（通过时非 null）
	var matched_imaginary_uuids: Array[String] = []  ## V8: 命中的 3 个 imaginary uuid
	var tried_combinations: int = 0        ## V8: 枚举的组合数（调试用）


## 主入口：诗词评价引擎 V8
## imaginaries: 所有拥有的 Imaginary 数组（不限 3 个）
## recipe_index: Database.recipe_index — {sorted_key → Poem recipe}
## mode: "deng_gao" | "gan_ye" — 覆盖 channel 乘数
static func calculate_poem_grade(imaginaries: Array, recipe_index: Dictionary, mode: String = "") -> PoemCraftingResult:
	var result = PoemCraftingResult.new()

	if imaginaries.size() < 3:
		result.passed = false
		result.fail_reason = "too_few"
		result.penalty_text = PENALTY_TEXT
		Logging.warn("PoemCraftingCalculator: 需要至少 3 个 Imaginary，实际 %d" % imaginaries.size())
		return result

	# ── 提取所有 valid Imaginary 的 uuid ──
	var uuids: Array[String] = []
	for imag in imaginaries:
		if imag is Imaginary and not imag.uuid.is_empty():
			uuids.append(imag.uuid.to_lower())

	if uuids.size() < 3:
		result.passed = false
		result.fail_reason = "too_few"
		result.penalty_text = PENALTY_TEXT
		Logging.warn("PoemCraftingCalculator: valid imaginary uuids < 3: %d" % uuids.size())
		return result

	# ── C(N,3) 枚举所有 3-组合 ──
	var n := uuids.size()
	var combo_count := 0
	for i in range(n - 2):
		for j in range(i + 1, n - 1):
			for k in range(j + 1, n):
				combo_count += 1
				var triplet: Array[String] = [uuids[i], uuids[j], uuids[k]]
				var lookup_key = FragmentMatcher.build_key(triplet)
				Logging.debug("PoemCraftingCalculator: combo #%d key=%s" % [combo_count, lookup_key])

				if recipe_index.has(lookup_key):
					result.matched_recipe = recipe_index[lookup_key]
					result.matched_imaginary_uuids = triplet
					Logging.info("PoemCraftingCalculator: 组合 #%d 命中食谱 %s (key=%s)" % [combo_count, result.matched_recipe.name, lookup_key])
					break
			if result.matched_recipe != null:
				break
		if result.matched_recipe != null:
			break

	result.tried_combinations = combo_count

	if result.matched_recipe == null:
		Logging.info("PoemCraftingCalculator: 枚举 %d 种组合，无匹配" % combo_count)
		result.passed = false
		result.fail_reason = "no_match"
		result.penalty_text = PENALTY_TEXT
		return result

	# ── 收益公式 ──
	var base_history := BASE_HISTORY
	var base_secular := BASE_SECULAR

	# V8: mode 覆盖 channel（优先级高于 recipe.specific_topic）
	var channel_group := ""
	if not mode.is_empty() and MODE_CHANNEL_MAP.has(mode):
		channel_group = MODE_CHANNEL_MAP[mode]
		Logging.info("PoemCraftingCalculator: mode '%s' → channel '%s' (overridden)" % [mode, channel_group])
	else:
		# 降级：从 recipe 的 specific_topic 推导 channel
		var recipe = result.matched_recipe
		if recipe and not recipe.specific_topic.is_empty():
			var poem_type = ENUMS.POEM_TYPE.get(recipe.specific_topic)
			if poem_type != null:
				channel_group = ENUMS.get_poem_type_channel(poem_type)
				Logging.info("PoemCraftingCalculator: recipe topic '%s' → channel '%s'" % [recipe.specific_topic, channel_group])

	if not channel_group.is_empty():
		var multipliers = CHANNEL_MATRIX.get(channel_group, {"history_mult": 1.0, "secular_mult": 1.0})
		base_history *= multipliers["history_mult"]
		base_secular *= multipliers["secular_mult"]
		Logging.info("PoemCraftingCalculator: channel=%s, multipliers=%s → secular=%f, literary=%f" % [channel_group, multipliers, base_secular, base_history])

	result.secular_value = base_secular
	result.literary_value = base_history

	# ── 算子生成（仅非零值）──
	if base_secular != 0:
		result.operators.append(OperatorFactory.create_property_operator("money", base_secular))
	if base_history != 0:
		result.operators.append(OperatorFactory.create_property_operator("literary_fame", base_history))

	result.passed = true
	Logging.info("PoemCraftingCalculator: 创作成功 — secular=%f, literary=%f, recipe=%s, imag=%s" %
		[base_secular, base_history, result.matched_recipe.name, str(result.matched_imaginary_uuids)])
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
