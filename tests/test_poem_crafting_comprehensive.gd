# ════════════════════════════════════════════════════════════
# 诗词创作系统 — V5 精确 Set 匹配集成测试
#
# 场景 1: 精确 Set 匹配 → 创作成功
# 场景 2: 2/3 子集匹配 → 打油诗
# 场景 3: <2 匹配 → 失败
# 场景 4: poem_level = max(levels) 验证
# 场景 5: Tier 2/3 合并验证
# 场景 6: Concept set 无序匹配验证
# ════════════════════════════════════════════════════════════
extends GutTest

const SEP = "============================================================"


func before_each():
	PlayerState.traits.clear()
	PlayerState.emotions.clear()
	PlayerState.flags.clear()
	PlayerState.created_poems.clear()
	Database.properties.clear()
	Database.imaginaries.clear()
	Database.imaginaries_detail.clear()
	Database.recipe_index.clear()


# ── 工具函数 ──

func _make_concept(key: String, tier: int, level: int = 2) -> ImaginaryConcept:
	var c = ImaginaryConcept.new()
	c.uuid = key
	c.current_tier = tier
	c.current_level = level
	return c

func _make_recipe(key: String, name: String, fragments: Array[String], specific_topic: String = "GAN_YE") -> Poem:
	var p = Poem.new("POEM", specific_topic, 0, 0.0, 0.0)
	p.uuid = key
	p.name = name
	p.required_fragments = fragments
	return p

func _build_index(recipes: Array[Poem]) -> Dictionary:
	var idx: Dictionary = {}
	for recipe in recipes:
		var key = FragmentMatcher.build_key(recipe.required_fragments)
		idx[key] = recipe
	return idx


# ════════════════════════════════════════════════════════════
# 场景 1: 精确 Set 匹配 → 创作成功
# ════════════════════════════════════════════════════════════

func test_scenario_1_exact_match():
	Logging.info(SEP)
	Logging.info("[场景1] 精确 Set 匹配 → 创作成功")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	var c1 = _make_concept("aesthetic:elegant", 2, 1)
	var c2 = _make_concept("emotion:ambition", 2, 1)
	var c3 = _make_concept("society:famine", 1, 1)

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)

	assert_true(result.passed, "精确匹配应通过")
	assert_false(result.is_doggerel, "不应为打油诗")
	assert_eq(result.matched_recipe, recipe, "应匹配到食谱")
	assert_eq(result.poem_level, 1, "poem_level = max(1,1,1) = 1")
	# min_tier: c1.tier=2(→2), c2.tier=2(→2), c3.tier=1 → min=1
	assert_eq(result.min_tier, 1, "min_tier 应为 1")
	Logging.info("[场景1] 完成 ✓: passed=%s, tier=%d, level=%d" % [result.passed, result.min_tier, result.poem_level])
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 2: 2/3 子集匹配 → 打油诗
# ════════════════════════════════════════════════════════════

func test_scenario_2_doggerel():
	Logging.info(SEP)
	Logging.info("[场景2] 2/3 子集匹配 → 打油诗")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# 提交 A, B, D — 其中 A, B 在食谱中，D 不在
	var c1 = _make_concept("aesthetic:elegant", 1, 1)
	var c2 = _make_concept("emotion:ambition", 1, 1)
	var c3 = _make_concept("theme:martial", 1, 1)  # D — 不在食谱中

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)

	assert_true(result.is_doggerel, "应为打油诗")
	assert_true(result.passed, "打油诗 passed 应为 true（可执行算子）")
	assert_eq(result.literary_value, 5.0, "打油诗 literary_fame 固定 +5")
	assert_eq(result.matched_recipe, null, "打油诗无匹配食谱")
	assert_eq(result.operators.size(), 1, "打油诗仅 1 个算子")

	Logging.info("[场景2] 完成 ✓: is_doggerel=%s, literary=%.0f" % [result.is_doggerel, result.literary_value])
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 3: <2 匹配 → 失败
# ════════════════════════════════════════════════════════════

func test_scenario_3_no_match():
	Logging.info(SEP)
	Logging.info("[场景3] <2 匹配 → 失败")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# 提交完全无关的 3 个 concept
	var c1 = _make_concept("theme:martial", 1, 1)
	var c2 = _make_concept("myth:animal", 1, 1)
	var c3 = _make_concept("finance:broke", 1, 1)

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)

	assert_false(result.passed, "无匹配应失败")
	assert_false(result.is_doggerel, "不应为打油诗")
	assert_eq(result.fail_reason, "no_match", "fail_reason 应为 no_match")

	Logging.info("[场景3] 完成 ✓: passed=%s, reason=%s" % [result.passed, result.fail_reason])
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 4: poem_level = max(levels) 验证
# ════════════════════════════════════════════════════════════

func test_scenario_4_poem_level_max():
	Logging.info(SEP)
	Logging.info("[场景4] poem_level = max(levels) 验证")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# levels: 0, 1, 2 → max = 2
	var c1 = _make_concept("aesthetic:elegant", 1, 0)
	var c2 = _make_concept("emotion:ambition", 1, 1)
	var c3 = _make_concept("society:famine", 1, 2)

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)
	assert_eq(result.poem_level, 2, "max(0,1,2) = 2")
	Logging.info("[场景4] poem_level = %d (期望 2)" % result.poem_level)

	# levels: 1, 1, 1 → max = 1
	var c4 = _make_concept("aesthetic:elegant", 1, 1)
	var c5 = _make_concept("emotion:ambition", 1, 1)
	var result2 = PoemCraftingCalculator.calculate_poem_grade([c4, c5, c3], idx)
	assert_eq(result2.poem_level, 2, "max(1,1,2) = 2")

	Logging.info("[场景4] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 5: Tier 2/3 合并验证
# ════════════════════════════════════════════════════════════

func test_scenario_5_tier_merge():
	Logging.info(SEP)
	Logging.info("[场景5] Tier 2/3 合并 → Tier >= 2 统一为 Tier 2")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# tier=3 会被 ImaginaryConcept setter clamp 到 2
	var c1 = _make_concept("aesthetic:elegant", 3, 1)
	Logging.info("[场景5] concept tier before clamp: %d (应为 2，已被 setter clamp)" % c1.current_tier)
	assert_eq(c1.current_tier, 2, "tier=3 应被 clamp 到 2")

	var c2 = _make_concept("emotion:ambition", 2, 1)
	var c3 = _make_concept("society:famine", 2, 1)

	# 所有 tier=2 → min_tier=2
	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)
	assert_eq(result.min_tier, 2, "min_tier 应为 2 (所有 concept tier>=2)")
	Logging.info("[场景5] min_tier=%d, base_history=%.0f, base_secular=%.0f" %
		[result.min_tier, result.literary_value, result.secular_value])

	Logging.info("[场景5] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 6: Concept Set 无序匹配验证
# ════════════════════════════════════════════════════════════

func test_scenario_6_unordered_match():
	Logging.info(SEP)
	Logging.info("[场景6] Concept Set 无序匹配 — 顺序无关")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# 不同顺序提交应全部匹配
	var c1 = _make_concept("society:famine", 1, 1)
	var c2 = _make_concept("aesthetic:elegant", 1, 1)
	var c3 = _make_concept("emotion:ambition", 1, 1)

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)
	assert_true(result.passed, "无序 Set 应精确匹配")
	assert_eq(result.matched_recipe, recipe)

	# 反向顺序
	var result2 = PoemCraftingCalculator.calculate_poem_grade([c3, c1, c2], idx)
	assert_true(result2.passed, "反向顺序也应匹配")

	Logging.info("[场景6] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 7: 食谱不匹配时检查 2/3（仅 1 个命中 → 失败）
# ════════════════════════════════════════════════════════════

func test_scenario_7_only_one_match():
	Logging.info(SEP)
	Logging.info("[场景7] 仅 1 个 concept 命中 → 失败（不够打油诗门槛）")
	Logging.info(SEP)

	var recipe = _make_recipe("recipe_test", "测试诗", ["aesthetic:elegant", "emotion:ambition", "society:famine"])
	var idx = _build_index([recipe])

	# 仅 1 个匹配
	var c1 = _make_concept("aesthetic:elegant", 1, 1)
	var c2 = _make_concept("theme:martial", 1, 1)
	var c3 = _make_concept("myth:animal", 1, 1)

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], idx)

	assert_false(result.passed, "仅 1 个命中应失败")
	assert_false(result.is_doggerel, "不够 2 个不应为打油诗")
	assert_eq(result.fail_reason, "no_match")

	Logging.info("[场景7] 完成 ✓")
	Logging.info(SEP)
