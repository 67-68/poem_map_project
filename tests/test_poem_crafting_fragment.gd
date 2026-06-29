# ════════════════════════════════════════════════════════════
# PoemCraftingCalculator — FragmentMatcher 双层校验集成测试
# 覆盖：required_fragments 传入后的通过/惩罚/优先级逻辑
# ════════════════════════════════════════════════════════════
extends GutTest


func before_each():
	PlayerState.traits.clear()
	PlayerState.emotions.clear()
	PlayerState.flags.clear()
	Database.properties.clear()
	Database.imaginaries.clear()
	Database.imaginaries_detail.clear()


func _make_concept(tier: int, level: int = 2) -> ImaginaryConcept:
	var c = ImaginaryConcept.new()
	c.uuid = "concept_%d_%d" % [tier, randi()]
	c.current_tier = tier
	c.current_level = level
	return c

func _make_imaginary(uuid: String, tags: Array[String]) -> Imaginary:
	var imag = Imaginary.new()
	imag.uuid = uuid
	imag.detail_imaginaries = tags
	return imag


# ════════════════════════════════════════════════════════════
# A. FragmentMatcher 通过场景
# ════════════════════════════════════════════════════════════

func test_fragment_match_pass_exact():
	"""双层校验：tier 通过 + fragment 精确匹配 → passed=true"""
	var concepts = [_make_concept(1), _make_concept(1)]
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:changanleaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["VIBE:THEME:MACABRE:ghostfire"])

	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire"
	]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_true(result.passed, "精确匹配权重 40>=30 → 通过")
	assert_eq(result.fail_reason, "")


func test_fragment_match_pass_partial_enough():
	"""3 条同类匹配 → 30 刚好过线"""
	var concepts = [_make_concept(1), _make_concept(1)]
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:beijingleaf"])

	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"ENV:NATURE:AUTUMN:luoyangleaf",
		"ENV:NATURE:AUTUMN:nanjingleaf"
	]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_true(result.passed, "3 条同类 → 30 刚过线")


# ════════════════════════════════════════════════════════════
# B. FragmentMatcher 失败惩罚
# ════════════════════════════════════════════════════════════

func test_fragment_match_fail_insufficient_weight():
	"""weight < 30 → fail_reason='fragment' + PENALTY_TEXT"""
	var concepts = [_make_concept(1), _make_concept(1)]
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:beijingleaf"])

	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"ENV:NATURE:AUTUMN:luoyangleaf"
	]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_false(result.passed, "weight=20<30 → 未通过")
	assert_eq(result.fail_reason, "fragment")
	assert_eq(result.penalty_text, PoemCraftingCalculator.PENALTY_TEXT)


func test_fragment_match_fail_no_match():
	"""玩家意象与诗词要求完全不相关 → weight=0"""
	var concepts = [_make_concept(1), _make_concept(1)]
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:GRASS:weed"])

	var required: Array[String] = ["VIBE:THEME:MACABRE:ghostfire"]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_false(result.passed)
	assert_eq(result.fail_reason, "fragment")


# ════════════════════════════════════════════════════════════
# C. 跳过 FragmentMatcher（无 required_fragments）
# ════════════════════════════════════════════════════════════

func test_no_required_fragments_skips_matcher():
	"""required_fragments 为空 → 仅 tier 校验，正常返回"""
	var concepts = [_make_concept(1), _make_concept(1)]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, [])
	assert_true(result.passed, "无 required_fragments 时仅 tier 校验")
	assert_eq(result.fail_reason, "")


# ════════════════════════════════════════════════════════════
# D. 优先级：虚伪反噬 > FragmentMatcher
# ════════════════════════════════════════════════════════════

func test_hypocrisy_trumps_fragment_match():
	"""IAM=zuanying + tier=3 → 虚伪反噬先触发，不走 FragmentMatcher"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)
	var concepts = [_make_concept(3), _make_concept(3)]
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:changanleaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["VIBE:THEME:MACABRE:ghostfire"])

	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire"
	]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_false(result.passed, "虚伪反噬优先于 FragmentMatcher")
	assert_eq(result.fail_reason, "tier", "fail_reason 应为 tier 而非 fragment")
	assert_eq(result.penalty_text, "[虚伪的拼凑者]")


# ════════════════════════════════════════════════════════════
# E. 无玩家意象但有 required_fragments
# ════════════════════════════════════════════════════════════

func test_empty_imaginaries_detail_but_has_required():
	"""玩家无任何 Imaginary → weight=0 → fail"""
	var concepts = [_make_concept(1), _make_concept(1)]

	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, -1, required)
	assert_false(result.passed)
	assert_eq(result.fail_reason, "fragment")
