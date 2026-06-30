# ════════════════════════════════════════════════════════════
# 诗词创作系统 — 综合集成测试（6 组场景）
#
# 场景 1: Imaginary 重叠 → merge 验证
# 场景 2: 3 个 partial match → 恰好 30 权重 + 匹配日志
# 场景 3: 无法匹配诗词 → 拒绝创作
# 场景 4: 2 partial + 1 无匹配 → 拒绝创作 + 报错
# 场景 5: PoemTypeChooseOperator 使用诗词后从 trait 面板删除
# 场景 6: Tier 1/2/3 + SECULAR/BROADCAST 管道乘数
# ════════════════════════════════════════════════════════════
extends GutTest

const SEP = "============================================================"


func before_each():
	PlayerState.traits.clear()
	PlayerState.emotions.clear()
	PlayerState.flags.clear()
	Database.properties.clear()
	Database.imaginaries.clear()
	Database.imaginaries_detail.clear()


# ── 工具函数 ──

func _make_concept(key: String, tier: int, level: int = 2) -> ImaginaryConcept:
	var c = ImaginaryConcept.new()
	c.uuid = key
	c.current_tier = tier
	c.current_level = level
	return c

func _make_imaginary(uuid: String, tags: Array[String]) -> Imaginary:
	var imag = Imaginary.new()
	imag.uuid = uuid
	imag.detail_imaginaries = tags
	return imag


# ════════════════════════════════════════════════════════════
# 场景 1: Imaginary 重叠 → merge 验证
# 2 个 Imaginary，其中 1 个抽象概念有 2 个 detailed imaginary
# 另外 2 个抽象概念各只有 1 个 → 可见但不可合并
# ════════════════════════════════════════════════════════════

func test_scenario_1_merge_overlap():
	Logging.info(SEP)
	Logging.info("[场景1] 开始: 2 个 Imaginary 重叠 → merge 验证")
	Logging.info(SEP)

	# Imaginary A: 跨 finance:broke + health:exhausted
	Database.imaginaries_detail["imag_a"] = _make_imaginary("imag_a", [
		"ACTOR:FINANCE:BROKE:imag_a",
		"ACTOR:HEALTH:EXHAUSTED:imag_a"
	])
	# Imaginary B: 跨 finance:broke + aesthetic:elegant
	Database.imaginaries_detail["imag_b"] = _make_imaginary("imag_b", [
		"ACTOR:FINANCE:BROKE:imag_b",
		"VIBE:AESTHETIC:ELEGANT:imag_b"
	])

	Logging.info("[场景1] 已注入 Imaginary A: detail=[ACTOR:FINANCE:BROKE:imag_a, ACTOR:HEALTH:EXHAUSTED:imag_a]")
	Logging.info("[场景1] 已注入 Imaginary B: detail=[ACTOR:FINANCE:BROKE:imag_b, VIBE:AESTHETIC:ELEGANT:imag_b]")

	# 推导概念分组
	var groups = ImaginaryComprehender._derive_concept_groups()
	Logging.info("[场景1] 概念分组结果: %s" % str(groups.keys()))

	# finance:broke 应有 2 个 Imaginary → 可合并
	var fin_imags = ImaginaryComprehender.get_imaginaries_for_concept("finance:broke")
	assert_eq(fin_imags.size(), 2, "finance:broke 应有 2 个 Imaginary")
	assert_true(ImaginaryComprehender.can_merge("finance:broke"), "finance:broke 可合并")

	# health:exhausted 只有 1 个 → 不可合并
	var health_imags = ImaginaryComprehender.get_imaginaries_for_concept("health:exhausted")
	assert_eq(health_imags.size(), 1, "health:exhausted 只有 1 个")
	assert_false(ImaginaryComprehender.can_merge("health:exhausted"), "health:exhausted 不可合并")

	# aesthetic:elegant 只有 1 个 → 不可合并
	var eleg_imags = ImaginaryComprehender.get_imaginaries_for_concept("aesthetic:elegant")
	assert_eq(eleg_imags.size(), 1, "aesthetic:elegant 只有 1 个")
	assert_false(ImaginaryComprehender.can_merge("aesthetic:elegant"), "aesthetic:elegant 不可合并")

	Logging.info("[场景1] 验证通过: finance:broke 可合并, 其余 2 个仅可见")
	Logging.info("[场景1] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 2: 3 个 partial match → 恰好 30 权重
# 诗词要求 A:B:C:D, 3 个概念各有一个 detail = A:B:C:E
# 每个 10 权重, 合计 30 = 刚好过线
# ════════════════════════════════════════════════════════════

func test_scenario_2_three_partial_exact_threshold():
	Logging.info(SEP)
	Logging.info("[场景2] 开始: 3 个 partial match → 恰好 30 权重")
	Logging.info(SEP)

	# 诗词要求: A:B:C:D (具体用 ENV:NATURE:AUTUMN:changanleaf)
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]

	# 3 个概念, 每个有 2 个 detail, 其中一个 partial match (A:B:C:E)
	# 概念 1: finance:broke, tier=1, level=2
	var c1 = _make_concept("finance:broke", 1, 2)
	Database.imaginaries_detail["img_c1a"] = _make_imaginary("img_c1a", [
		"ACTOR:FINANCE:BROKE:img_c1a",
		"ENV:NATURE:AUTUMN:beijingleaf"    # ← partial match (同类)
	])
	Database.imaginaries_detail["img_c1b"] = _make_imaginary("img_c1b", [
		"ACTOR:FINANCE:BROKE:img_c1b",
		"VIBE:AESTHETIC:ELEGANT:img_c1b"
	])
	Logging.info("[场景2] 概念1 finance:broke: ENV:NATURE:AUTUMN:beijingleaf (同类=10)")

	# 概念 2: health:exhausted, tier=1, level=2
	var c2 = _make_concept("health:exhausted", 1, 2)
	Database.imaginaries_detail["img_c2a"] = _make_imaginary("img_c2a", [
		"ACTOR:HEALTH:EXHAUSTED:img_c2a",
		"ENV:NATURE:AUTUMN:luoyangleaf"    # ← partial match
	])
	Database.imaginaries_detail["img_c2b"] = _make_imaginary("img_c2b", [
		"ACTOR:HEALTH:EXHAUSTED:img_c2b",
		"VIBE:THEME:MARTIAL:img_c2b"
	])
	Logging.info("[场景2] 概念2 health:exhausted: ENV:NATURE:AUTUMN:luoyangleaf (同类=10)")

	# 概念 3: society:famine, tier=1, level=2
	var c3 = _make_concept("society:famine", 1, 2)
	Database.imaginaries_detail["img_c3a"] = _make_imaginary("img_c3a", [
		"ENV:SOCIETY:FAMINE:img_c3a",
		"ENV:NATURE:AUTUMN:nanjingleaf"    # ← partial match
	])
	Database.imaginaries_detail["img_c3b"] = _make_imaginary("img_c3b", [
		"ENV:SOCIETY:FAMINE:img_c3b",
		"ACTOR:EMOTION:SORROW:img_c3b"
	])
	Logging.info("[场景2] 概念3 society:famine: ENV:NATURE:AUTUMN:nanjingleaf (同类=10)")

	# 执行匹配
	var weight = FragmentMatcher.match_concepts([c1, c2, c3], required)
	Logging.info("[场景2] FragmentMatcher 匹配结果: weight=%d (threshold=%d)" % [weight, FragmentMatcher.THRESHOLD])

	assert_eq(weight, 30, "3 个同类=10 合计 30, 刚好过线")

	# 验证 PoemCraftingCalculator
	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], -1, required)
	Logging.info("[场景2] PoemCraftingCalculator: passed=%s, weight=%d" % [result.passed, weight])
	assert_true(result.passed, "权重 30 >= 阈值 30 → 通过")
	assert_eq(result.fail_reason, "")

	Logging.info("[场景2] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 3: 3 个 category 无法匹配诗词 → 拒绝创作
# 诗词要求 A:B:C:D, 但所有意象都不相关
# ════════════════════════════════════════════════════════════

func test_scenario_3_no_match_rejected():
	Logging.info(SEP)
	Logging.info("[场景3] 开始: 3 个 category 无法匹配 → 拒绝创作")
	Logging.info(SEP)

	# 诗词要求 ENV:NATURE:AUTUMN:changanleaf
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]

	# 3 个概念, 全部不匹配
	var c1 = _make_concept("health:drunk", 1, 2)
	Database.imaginaries_detail["img_d1a"] = _make_imaginary("img_d1a", [
		"ACTOR:HEALTH:DRUNK:img_d1a",
		"VIBE:AESTHETIC:SENSUAL:img_d1a"
	])
	Database.imaginaries_detail["img_d1b"] = _make_imaginary("img_d1b", [
		"ACTOR:HEALTH:DRUNK:img_d1b",
		"ACTOR:EMOTION:ARROGANCE:img_d1b"
	])
	Logging.info("[场景3] 概念1 health:drunk: 碎片与 ENV:NATURE:AUTUMN 无关")

	var c2 = _make_concept("emotion:ambition", 1, 2)
	Database.imaginaries_detail["img_d2a"] = _make_imaginary("img_d2a", [
		"ACTOR:EMOTION:AMBITION:img_d2a",
		"TARGET:MYTH:ANIMAL:img_d2a"
	])
	Database.imaginaries_detail["img_d2b"] = _make_imaginary("img_d2b", [
		"ACTOR:EMOTION:AMBITION:img_d2b",
		"VIBE:THEME:MARTIAL:img_d2b"
	])
	Logging.info("[场景3] 概念2 emotion:ambition: 碎片与 ENV:NATURE:AUTUMN 无关")

	var c3 = _make_concept("society:war", 1, 2)
	Database.imaginaries_detail["img_d3a"] = _make_imaginary("img_d3a", [
		"ENV:SOCIETY:WAR:img_d3a",
		"VIBE:THEME:HISTORY:img_d3a"
	])
	Database.imaginaries_detail["img_d3b"] = _make_imaginary("img_d3b", [
		"ENV:SOCIETY:WAR:img_d3b",
		"ACTOR:EMOTION:ANGER:img_d3b"
	])
	Logging.info("[场景3] 概念3 society:war: 碎片与 ENV:NATURE:AUTUMN 无关")

	var weight = FragmentMatcher.match_concepts([c1, c2, c3], required)
	Logging.info("[场景3] FragmentMatcher: weight=%d (threshold=%d)" % [weight, FragmentMatcher.THRESHOLD])
	assert_eq(weight, 0, "完全不匹配 → weight=0")

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], -1, required)
	Logging.info("[场景3] PoemCraftingCalculator: passed=%s, fail_reason='%s'" % [result.passed, result.fail_reason])
	assert_false(result.passed, "应拒绝创作")
	assert_eq(result.fail_reason, "fragment")
	assert_eq(result.penalty_text, PoemCraftingCalculator.PENALTY_TEXT)

	Logging.info("[场景3] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 4: 2 partial + 1 无匹配 → 拒绝创作 + 报错
# 诗词要求 A:B:C:D, 2 个有 partial match (10+10=20), 1 个无匹配
# 合计 20 < 30 → 拒绝
# ════════════════════════════════════════════════════════════

func test_scenario_4_two_partial_one_none_rejected():
	Logging.info(SEP)
	Logging.info("[场景4] 开始: 2 partial match (20) + 1 无匹配 → 拒绝")
	Logging.info(SEP)

	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]

	# 概念 1: 有 partial match
	var c1 = _make_concept("finance:broke", 1, 2)
	Database.imaginaries_detail["img_e1a"] = _make_imaginary("img_e1a", [
		"ACTOR:FINANCE:BROKE:img_e1a",
		"ENV:NATURE:AUTUMN:beijingleaf"   # ← 同类 10
	])
	Database.imaginaries_detail["img_e1b"] = _make_imaginary("img_e1b", [
		"ACTOR:FINANCE:BROKE:img_e1b",
		"ACTOR:HEALTH:EXHAUSTED:img_e1b"
	])
	Logging.info("[场景4] 概念1 finance:broke: 有 partial (10)")

	# 概念 2: 有 partial match
	var c2 = _make_concept("health:exhausted", 1, 2)
	Database.imaginaries_detail["img_e2a"] = _make_imaginary("img_e2a", [
		"ACTOR:HEALTH:EXHAUSTED:img_e2a",
		"ENV:NATURE:AUTUMN:luoyangleaf"   # ← 同类 10
	])
	Database.imaginaries_detail["img_e2b"] = _make_imaginary("img_e2b", [
		"ACTOR:HEALTH:EXHAUSTED:img_e2b",
		"VIBE:THEME:MARTIAL:img_e2b"
	])
	Logging.info("[场景4] 概念2 health:exhausted: 有 partial (10)")

	# 概念 3: 完全无匹配
	var c3 = _make_concept("emotion:sorrow", 1, 2)
	Database.imaginaries_detail["img_e3a"] = _make_imaginary("img_e3a", [
		"ACTOR:EMOTION:SORROW:img_e3a",
		"VIBE:THEME:HISTORY:img_e3a"
	])
	Database.imaginaries_detail["img_e3b"] = _make_imaginary("img_e3b", [
		"ACTOR:EMOTION:SORROW:img_e3b",
		"ENV:SOCIETY:FAMINE:img_e3b"
	])
	Logging.info("[场景4] 概念3 emotion:sorrow: 无匹配 (0)")

	var weight = FragmentMatcher.match_concepts([c1, c2, c3], required)
	Logging.info("[场景4] FragmentMatcher: weight=%d (10+10+0=20, threshold=%d)" % [weight, FragmentMatcher.THRESHOLD])
	assert_eq(weight, 20, "2 个同类 → 20")

	var result = PoemCraftingCalculator.calculate_poem_grade([c1, c2, c3], -1, required)
	Logging.info("[场景4] PoemCraftingCalculator: passed=%s, fail_reason='%s', penalty='%s'" % [result.passed, result.fail_reason, result.penalty_text])
	assert_false(result.passed, "20 < 30 → 应拒绝")
	assert_eq(result.fail_reason, "fragment")
	assert_true(result.penalty_text.contains("意象散乱"), "惩罚文案应包含意象散乱")

	Logging.info("[场景4] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 5: PoemTypeChooseOperator 使用诗词后从 trait 面板删除
# 验证: add_trait → PoemTypeChooseOperator._on_trait_picked → remove_trait
# ════════════════════════════════════════════════════════════

func test_scenario_5_poem_choose_removes_trait():
	Logging.info(SEP)
	Logging.info("[场景5] 开始: PoemTypeChooseOperator 使用诗词后删除 trait")
	Logging.info(SEP)

	# 创建一首诗词 trait
	var poem = Poem.new("POEM", "GAN_YE", 1, 100.0, 50.0)
	poem.uuid = "test_poem_gan_ye_1"
	poem.name = "测试干谒诗"
	PlayerState.add_trait("test_poem_gan_ye_1")
	Logging.info("[场景5] 已添加诗词 trait: test_poem_gan_ye_1 (GAN_YE, level=1)")

	# 验证 trait 存在
	assert_true(PlayerState.has_trait("test_poem_gan_ye_1"), "trait 应存在")

	# 模拟 PoemTypeChooseOperator 选中后的删除逻辑
	PlayerState.remove_trait("test_poem_gan_ye_1")
	Logging.info("[场景5] 已调用 remove_trait('test_poem_gan_ye_1')")

	# 验证 trait 已删除
	assert_false(PlayerState.has_trait("test_poem_gan_ye_1"), "trait 应已删除")
	Logging.info("[场景5] 验证: trait 已从面板移除")

	Logging.info("[场景5] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 场景 6: Tier 1/2/3 概念在不同诗词类型下的世俗值/千古值
# GAN_YE (SECULAR) vs DENG_GAO (BROADCAST) 管道乘数差异
# ════════════════════════════════════════════════════════════

func test_scenario_6_tier_values_by_poem_type():
	Logging.info(SEP)
	Logging.info("[场景6] 开始: Tier 1/2/3 在不同诗词类型下的收益差异")
	Logging.info(SEP)

	# ── Tier 1: SECULAR vs BROADCAST ──
	Logging.info("--- Tier 1 测试 ---")

	var c_t1_a = _make_concept("finance:broke", 1, 1)
	var c_t1_b = _make_concept("health:exhausted", 1, 1)

	# SECULAR (GAN_YE): history_mult=0.0, secular_mult=1.5
	# base_secular = total_level * 10 = 2 * 10 = 20
	# base_secular *= 1.5 = 30
	var r_t1_secular = PoemCraftingCalculator.calculate_poem_grade(
		[c_t1_a, c_t1_b], ENUMS.POEM_TYPE.GAN_YE, [])
	assert_true(r_t1_secular.passed)
	Logging.info("[场景6] Tier1 + GAN_YE(SECULAR): secular=%.0f, literary=%.0f" % [r_t1_secular.secular_value, r_t1_secular.literary_value])
	assert_gt(r_t1_secular.secular_value, 0, "SECULAR Tier1 应有世俗收益")
	assert_eq(r_t1_secular.literary_value, 0.0, "SECULAR Tier1 千古值应为 0 (history_mult=0)")

	# BROADCAST (DENG_GAO): history_mult=0.0, secular_mult=0.0
	var r_t1_broadcast = PoemCraftingCalculator.calculate_poem_grade(
		[c_t1_a, c_t1_b], ENUMS.POEM_TYPE.DENG_GAO, [])
	assert_true(r_t1_broadcast.passed)
	Logging.info("[场景6] Tier1 + DENG_GAO(BROADCAST): secular=%.0f, literary=%.0f" % [r_t1_broadcast.secular_value, r_t1_broadcast.literary_value])
	assert_eq(r_t1_broadcast.secular_value, 0.0, "BROADCAST Tier1 世俗值应为 0")
	assert_eq(r_t1_broadcast.literary_value, 0.0, "BROADCAST Tier1 千古值应为 0")

	# ── Tier 2: SECULAR vs BROADCAST ──
	Logging.info("--- Tier 2 测试 ---")

	var c_t2_a = _make_concept("society:famine", 2, 2)
	var c_t2_b = _make_concept("emotion:sorrow", 2, 2)

	# SECULAR: history_mult=1.0, secular_mult=3.0
	# base_history = total_level * 15 = 4 * 15 = 60
	# base_secular = total_level * (-20) = 4 * (-20) = -80
	var r_t2_secular = PoemCraftingCalculator.calculate_poem_grade(
		[c_t2_a, c_t2_b], ENUMS.POEM_TYPE.GAN_YE, [])
	Logging.info("[场景6] Tier2 + GAN_YE(SECULAR): secular=%.0f, literary=%.0f" % [r_t2_secular.secular_value, r_t2_secular.literary_value])

	# BROADCAST: history_mult=1.2, secular_mult=0.0
	var r_t2_broadcast = PoemCraftingCalculator.calculate_poem_grade(
		[c_t2_a, c_t2_b], ENUMS.POEM_TYPE.DENG_GAO, [])
	Logging.info("[场景6] Tier2 + DENG_GAO(BROADCAST): secular=%.0f, literary=%.0f" % [r_t2_broadcast.secular_value, r_t2_broadcast.literary_value])

	# Tier 2 的一个重要差异: SECULAR 有金钱惩罚, BROADCAST 没有
	assert_ne(r_t2_secular.secular_value, r_t2_broadcast.secular_value,
		"Tier2 SECULAR vs BROADCAST 的世俗值应不同")

	# ── Tier 3: SECULAR vs BROADCAST ──
	Logging.info("--- Tier 3 测试 ---")

	var c_t3_a = _make_concept("emotion:ambition", 3, 2)
	var c_t3_b = _make_concept("myth:animal", 3, 2)

	# SECULAR: history_mult=1.0, secular_mult=0.0
	var r_t3_secular = PoemCraftingCalculator.calculate_poem_grade(
		[c_t3_a, c_t3_b], ENUMS.POEM_TYPE.GAN_YE, [])
	Logging.info("[场景6] Tier3 + GAN_YE(SECULAR): secular=%.0f, literary=%.0f" % [r_t3_secular.secular_value, r_t3_secular.literary_value])

	# BROADCAST: history_mult=1.5, secular_mult=0.0
	var r_t3_broadcast = PoemCraftingCalculator.calculate_poem_grade(
		[c_t3_a, c_t3_b], ENUMS.POEM_TYPE.DENG_GAO, [])
	Logging.info("[场景6] Tier3 + DENG_GAO(BROADCAST): secular=%.0f, literary=%.0f" % [r_t3_broadcast.secular_value, r_t3_broadcast.literary_value])

	# Tier 3: BROADCAST 的千古值应该更高 (1.5 乘数)
	assert_gt(r_t3_broadcast.literary_value, r_t3_secular.literary_value,
		"Tier3 BROADCAST 千古值应 > SECULAR (1.5x vs 1.0x 乘数)")

	Logging.info("[场景6] 完成 ✓")
	Logging.info(SEP)


# ════════════════════════════════════════════════════════════
# 额外: 验证虚伪反噬 (IAM=zuanying + tier=3) 优先级
# ════════════════════════════════════════════════════════════

func test_hypocrisy_backlash_priority():
	Logging.info(SEP)
	Logging.info("[额外] 虚伪反噬优先级验证")
	Logging.info(SEP)

	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)
	var c = _make_concept("myth:animal", 3, 2)
	Database.imaginaries_detail["img_z"] = _make_imaginary("img_z", [
		"TARGET:MYTH:ANIMAL:img_z",
		"VIBE:THEME:MARTIAL:img_z"
	])

	var required: Array[String] = ["VIBE:THEME:MARTIAL:img_z"]
	var result = PoemCraftingCalculator.calculate_poem_grade([c], -1, required)
	Logging.info("[额外] 虚伪反噬: passed=%s, fail_reason='%s', penalty='%s'" % [result.passed, result.fail_reason, result.penalty_text])
	assert_false(result.passed, "虚伪反噬应阻断")
	assert_eq(result.fail_reason, "tier", "fail_reason 应为 tier（优先于 fragment）")

	Logging.info("[额外] 完成 ✓")
	Logging.info(SEP)
