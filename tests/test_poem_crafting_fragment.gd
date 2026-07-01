# ════════════════════════════════════════════════════════════
# PoemCraftingCalculator — V5 FragmentMatcher 精确 Set 匹配测试
# 覆盖：build_key / count_matches / is_exact_match / 2/3 检测
# ════════════════════════════════════════════════════════════
extends GutTest


func before_each():
	PlayerState.traits.clear()
	PlayerState.emotions.clear()
	PlayerState.flags.clear()
	PlayerState.created_poems.clear()
	Database.properties.clear()
	Database.imaginaries.clear()
	Database.imaginaries_detail.clear()
	Database.recipe_index.clear()


func _make_concept(key: String, tier: int, level: int = 2) -> ImaginaryConcept:
	var c = ImaginaryConcept.new()
	c.uuid = key
	c.current_tier = tier
	return c

func _make_recipe(key: String, fragments: Array[String]) -> Poem:
	var p = Poem.new("POEM", "GAN_YE", 0, 0.0, 0.0)
	p.uuid = key
	p.name = key
	p.required_fragments = fragments
	return p

func _build_index(recipes: Array[Poem]) -> Dictionary:
	var idx: Dictionary = {}
	for recipe in recipes:
		var k = FragmentMatcher.build_key(recipe.required_fragments)
		idx[k] = recipe
	return idx


# ════════════════════════════════════════════════════════════
# A. FragmentMatcher.build_key 测试
# ════════════════════════════════════════════════════════════

func test_build_key_sorts():
	var key = FragmentMatcher.build_key(["c:z", "a:x", "b:y"])
	assert_eq(key, "a:x|b:y|c:z", "应排序后拼接")

func test_build_key_already_sorted():
	var key = FragmentMatcher.build_key(["a:x", "b:y", "c:z"])
	assert_eq(key, "a:x|b:y|c:z", "已排序应不变")


# ════════════════════════════════════════════════════════════
# B. FragmentMatcher.count_matches 测试
# ════════════════════════════════════════════════════════════

func test_count_matches_exact_3():
	var count = FragmentMatcher.count_matches(
		["a:x", "b:y", "c:z"],
		["a:x", "b:y", "c:z"]
	)
	assert_eq(count, 3, "3/3 全匹配")

func test_count_matches_partial_2():
	var count = FragmentMatcher.count_matches(
		["a:x", "b:y", "d:w"],
		["a:x", "b:y", "c:z"]
	)
	assert_eq(count, 2, "2/3 匹配")

func test_count_matches_none():
	var count = FragmentMatcher.count_matches(
		["d:w", "e:v", "f:u"],
		["a:x", "b:y", "c:z"]
	)
	assert_eq(count, 0, "0/3 匹配")

func test_count_matches_case_insensitive():
	var count = FragmentMatcher.count_matches(
		["Aesthetic:Elegant", "Emotion:Ambition"],
		["aesthetic:elegant", "emotion:ambition", "society:famine"]
	)
	assert_eq(count, 2, "大小写不敏感匹配")


# ════════════════════════════════════════════════════════════
# C. FragmentMatcher.is_exact_match 测试
# ════════════════════════════════════════════════════════════

func test_is_exact_match_true():
	assert_true(FragmentMatcher.is_exact_match(
		["a:x", "b:y", "c:z"],
		["a:x", "b:y", "c:z"]
	), "应精确匹配")

func test_is_exact_match_false_size():
	assert_false(FragmentMatcher.is_exact_match(
		["a:x", "b:y"],
		["a:x", "b:y", "c:z"]
	), "大小不同不匹配")

func test_is_exact_match_false_content():
	assert_false(FragmentMatcher.is_exact_match(
		["a:x", "b:y", "d:w"],
		["a:x", "b:y", "c:z"]
	), "内容不同不匹配")


# ════════════════════════════════════════════════════════════
# D. 旧接口 match_concepts 向后兼容（返回 int）
# ════════════════════════════════════════════════════════════

func test_match_concepts_v4_compat():
	var concepts = [_make_concept("a:x", 1), _make_concept("b:y", 1)]
	var result = FragmentMatcher.match_concepts(concepts, ["a:x", "b:y", "c:z"])
	assert_eq(result, 2, "旧接口应返回匹配数量")


# ════════════════════════════════════════════════════════════
# E. 精确匹配 → 打油诗 → 失败 完整链路
# ════════════════════════════════════════════════════════════

func test_full_chain_exact():
	var recipe = _make_recipe("r1", ["a:x", "b:y", "c:z"])
	var idx = _build_index([recipe])
	var result = PoemCraftingCalculator.calculate_poem_grade(
		[_make_concept("a:x", 1), _make_concept("b:y", 1), _make_concept("c:z", 1)], idx
	)
	assert_true(result.passed)
	assert_false(result.is_doggerel)

func test_full_chain_doggerel():
	var recipe = _make_recipe("r1", ["a:x", "b:y", "c:z"])
	var idx = _build_index([recipe])
	var result = PoemCraftingCalculator.calculate_poem_grade(
		[_make_concept("a:x", 1), _make_concept("b:y", 1), _make_concept("d:w", 1)], idx
	)
	assert_true(result.is_doggerel)
	assert_eq(result.literary_value, 5.0)

func test_full_chain_fail():
	var recipe = _make_recipe("r1", ["a:x", "b:y", "c:z"])
	var idx = _build_index([recipe])
	var result = PoemCraftingCalculator.calculate_poem_grade(
		[_make_concept("a:x", 1), _make_concept("d:w", 1), _make_concept("e:v", 1)], idx
	)
	assert_false(result.passed)
	assert_false(result.is_doggerel)
	assert_eq(result.fail_reason, "no_match")


# ════════════════════════════════════════════════════════════
# F. 多食谱精确匹配（不会误匹配到其他食谱）
# ════════════════════════════════════════════════════════════

func test_multiple_recipes_exact():
	var r1 = _make_recipe("r1", ["a:x", "b:y", "c:z"])
	var r2 = _make_recipe("r2", ["d:w", "e:v", "f:u"])
	var idx = _build_index([r1, r2])

	var result = PoemCraftingCalculator.calculate_poem_grade(
		[_make_concept("a:x", 1), _make_concept("b:y", 1), _make_concept("c:z", 1)], idx
	)
	assert_true(result.passed)
	assert_eq(result.matched_recipe, r1, "应匹配到 r1 而非 r2")


# ════════════════════════════════════════════════════════════
# G. 空食谱索引 → 直接失败
# ════════════════════════════════════════════════════════════

func test_empty_index_fails():
	var result = PoemCraftingCalculator.calculate_poem_grade(
		[_make_concept("a:x", 1), _make_concept("b:y", 1), _make_concept("c:z", 1)], {}
	)
	assert_false(result.passed)
	assert_false(result.is_doggerel)
	assert_eq(result.fail_reason, "no_match")
