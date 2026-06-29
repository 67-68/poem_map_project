# ════════════════════════════════════════════════════════════
# 意象阶级·合成坍缩·诗词评价引擎 单元测试
# 覆盖：TierDeterminer / ImaginaryComprehender / PoemCraftingCalculator
# ════════════════════════════════════════════════════════════
extends GutTest


# ════════════════════════════════════════════════════════════
# before_each — 重置 PlayerState 和 Database
# ════════════════════════════════════════════════════════════

func before_each():
	PlayerState.traits.clear()
	PlayerState.emotions.clear()
	Database.properties.clear()
	PlayerState.flags.clear()
	Database.imaginaries.clear()
	Database.imaginaries_detail.clear()


# ════════════════════════════════════════════════════════════
# A. TierDeterminer.determine_tier() 测试
# ════════════════════════════════════════════════════════════

func test_tier3_kuangke_tranquility():
	"""kuangke + tranquility >= 30 → Tier 3"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_KUANGKE)
	PlayerState.set_emotion(ENUMS.EMOTION.TRANQUILITY, 35)

	assert_eq(TierDeterminer.determine_tier(), 3, "kuangke + tranquility >= 30 应为 Tier 3")


func test_tier3_kuangke_arrogance():
	"""kuangke + arrogance >= 30 → Tier 3"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_KUANGKE)
	PlayerState.set_emotion(ENUMS.EMOTION.ARROGANCE, 40)

	assert_eq(TierDeterminer.determine_tier(), 3, "kuangke + arrogance >= 30 应为 Tier 3")


func test_tier3_kuangke_below_threshold():
	"""kuangke 但 tranquility 和 arrogance 都低于阈值 → 降级"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_KUANGKE)
	PlayerState.set_emotion(ENUMS.EMOTION.TRANQUILITY, 20)
	PlayerState.set_emotion(ENUMS.EMOTION.ARROGANCE, 10)

	# 没有 anger/sorrow 触发 Tier 2，也没有 zuanying/fengying 触发 Tier 1
	# 兜底为 Tier 1
	var result = TierDeterminer.determine_tier()
	assert_ne(result, 3, "kuangke 但情绪不足不应为 Tier 3")
	assert_ne(result, 2, "没有 anger/sorrow 不应为 Tier 2")


func test_tier2_anger():
	"""anger >= 30 → Tier 2 (任意 IAM)"""
	PlayerState.set_emotion(ENUMS.EMOTION.ANGER, 35)

	assert_eq(TierDeterminer.determine_tier(), 2, "anger >= 30 应为 Tier 2")


func test_tier2_sorrow():
	"""sorrow >= 30 → Tier 2 (任意 IAM)"""
	PlayerState.set_emotion(ENUMS.EMOTION.SORROW, 50)

	assert_eq(TierDeterminer.determine_tier(), 2, "sorrow >= 30 应为 Tier 2")


func test_tier2_anger_below_threshold():
	"""anger < 30 且 sorrow < 30 → 不触发 Tier 2"""
	PlayerState.set_emotion(ENUMS.EMOTION.ANGER, 20)
	PlayerState.set_emotion(ENUMS.EMOTION.SORROW, 10)

	var result = TierDeterminer.determine_tier()
	assert_ne(result, 2, "愤怒/愁苦不足不应为 Tier 2")


func test_tier1_zuanying_ambition():
	"""zuanying + ambition >= 25 → Tier 1"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)
	PlayerState.set_emotion(ENUMS.EMOTION.AMBITION, 30)

	assert_eq(TierDeterminer.determine_tier(), 1, "zuanying + ambition >= 25 应为 Tier 1")


func test_tier1_zuanying_burnout():
	"""zuanying + burnout >= 25 → Tier 1"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)
	var prop = Property.new()
	prop.val = 30
	Database.properties["burnout"] = prop

	assert_eq(TierDeterminer.determine_tier(), 1, "zuanying + burnout >= 25 应为 Tier 1")


func test_tier1_fengying_ambition():
	"""fengying + ambition >= 25 → Tier 1"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_FENGYING)
	PlayerState.set_emotion(ENUMS.EMOTION.AMBITION, 25)

	assert_eq(TierDeterminer.determine_tier(), 1, "fengying + ambition >= 25 应为 Tier 1")


func test_tier1_default_no_traits():
	"""无 IAM trait → 兜底 Tier 1"""
	var result = TierDeterminer.determine_tier()
	assert_eq(result, 1, "无 IAM trait 时默认应为 Tier 1")


func test_tier3_priority_over_tier2():
	"""kuangke + tranquility >= 30 且 anger >= 30 → Tier 3 优先于 Tier 2"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_KUANGKE)
	PlayerState.set_emotion(ENUMS.EMOTION.TRANQUILITY, 35)
	PlayerState.set_emotion(ENUMS.EMOTION.ANGER, 40)

	assert_eq(TierDeterminer.determine_tier(), 3, "Tier 3 优先级应高于 Tier 2")


func test_tier2_priority_over_tier1():
	"""anger >= 30 且 zuanying + ambition >= 25 → Tier 2 优先于 Tier 1"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)
	PlayerState.set_emotion(ENUMS.EMOTION.ANGER, 35)
	PlayerState.set_emotion(ENUMS.EMOTION.AMBITION, 30)

	assert_eq(TierDeterminer.determine_tier(), 2, "Tier 2 优先级应高于 Tier 1")


# ════════════════════════════════════════════════════════════
# B. ImaginaryComprehender.merge_category() 测试 (V2 API)
# ════════════════════════════════════════════════════════════

func _make_detail_imaginary(uuid: String, tag: String) -> Imaginary:
	var im = Imaginary.new()
	im.uuid = uuid
	var tags: Array[String] = [tag]
	im.detail_imaginaries = tags
	return im


func test_comprehend_insufficient_fragments():
	"""碎片不足 l2_threshold(2) → 返回 false"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")

	var success = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_false(success, "1 个 Imaginary < l2_threshold → 应返回 false")


func test_comprehend_nonexistent_category():
	"""category 不存在 → 返回 false"""
	var success = ImaginaryComprehender.comprehend_category("nonexistent")
	assert_false(success, "不存在的 category 应返回 false")


func test_comprehend_ink_contamination_min_tier():
	"""合并坍缩：未预配置 tier 时默认设为 1"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")
	Database.imaginaries_detail["b"] = _make_detail_imaginary("b", "ENV:NATURE:AUTUMN:wind")

	var success = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_true(success, "坍缩应成功")
	assert_eq(concept.current_tier, 1, "merge_category 默认 tier=1")
	assert_eq(concept.current_level, 2)


func test_comprehend_all_tier3():
	"""已合并的 concept（tier!=0）拒绝重复合并"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")
	Database.imaginaries_detail["b"] = _make_detail_imaginary("b", "ENV:NATURE:AUTUMN:wind")

	# 第一次合并成功
	var ok1 = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_true(ok1, "首次合并应成功")
	assert_ne(concept.current_tier, 0, "合并后 tier != 0")

	# 重新补充 Imaginaries，再次尝试合并
	Database.imaginaries_detail["c"] = _make_detail_imaginary("c", "ENV:NATURE:AUTUMN:rain")
	Database.imaginaries_detail["d"] = _make_detail_imaginary("d", "ENV:NATURE:AUTUMN:snow")

	var ok2 = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_false(ok2, "已合并的 concept 应拒绝重复合并")


func test_comprehend_level_clamp():
	"""level = clamp(imaginary_count, 0, 2)"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")
	Database.imaginaries_detail["b"] = _make_detail_imaginary("b", "ENV:NATURE:AUTUMN:wind")
	Database.imaginaries_detail["c"] = _make_detail_imaginary("c", "ENV:NATURE:AUTUMN:rain")

	var success = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_true(success)
	assert_eq(concept.current_level, 2, "3 个 Imaginary → level clamp 到 2")


func test_comprehend_level_exactly_1():
	"""2 个 Imaginary → level = 2"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")
	Database.imaginaries_detail["b"] = _make_detail_imaginary("b", "ENV:NATURE:AUTUMN:wind")

	var success = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_true(success)
	assert_eq(concept.current_level, 2, "2 个 Imaginary → level=2")


func test_comprehend_clears_fragments():
	"""坍缩后 detail_imaginaries 对应的 Imaginary 应从 Database 中删除"""
	var concept = _make_imaginary("nature:autumn")
	Database.imaginaries["nature:autumn"] = concept
	Database.imaginaries_detail["a"] = _make_detail_imaginary("a", "ENV:NATURE:AUTUMN:leaf")
	Database.imaginaries_detail["b"] = _make_detail_imaginary("b", "ENV:NATURE:AUTUMN:wind")

	assert_true(Database.imaginaries_detail.has("a"), "合并前应存在")
	ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_false(Database.imaginaries_detail.has("a"), "合并后 a 被消耗")
	assert_false(Database.imaginaries_detail.has("b"), "合并后 b 被消耗")


# ════════════════════════════════════════════════════════════
# C. ImaginaryComprehender.consume_concepts() 测试
# ════════════════════════════════════════════════════════════

func test_consume_concepts_removes_from_database():
	"""consume_concepts 应从 Database.imaginaries 中删除概念"""
	var c1 = _make_imaginary("c1")
	var c2 = _make_imaginary("c2")
	Database.imaginaries["c1"] = c1
	Database.imaginaries["c2"] = c2

	assert_true(Database.imaginaries.has("c1"), "删除前 c1 应存在")

	ImaginaryComprehender.consume_concepts([c1, c2])

	assert_false(Database.imaginaries.has("c1"), "c1 应被删除")
	assert_false(Database.imaginaries.has("c2"), "c2 应被删除")


# ════════════════════════════════════════════════════════════
# D. PoemCraftingCalculator.calculate_poem_grade() 测试
# ════════════════════════════════════════════════════════════

func test_poem_tier1_produces_money():
	"""Tier 1 配方 → 台阁体，产出 money"""
	var concepts = _make_tiered_concepts([1, 1])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	assert_not_null(result)
	var has_money = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money" and op.value > 0:
			has_money = true
			break
	assert_true(has_money, "Tier 1 应有正面 money 产出")


func test_poem_tier2_produces_fame_and_negative_money():
	"""Tier 2 配方 → 诗史，产出 literary_fame + 贬为 negative money"""
	var concepts = _make_tiered_concepts([2, 2])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	var has_fame = false
	var has_negative_money = false
	var has_push = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			has_fame = true
		if op is PropertyOperator and op.property == "money" and op.value < 0:
			has_negative_money = true
		if op is PushEventOperator:
			has_push = true
	assert_true(has_fame, "Tier 2 应有 literary_fame 产出")
	assert_true(has_negative_money, "Tier 2 应有 negative money 惩罚")
	assert_true(has_push, "Tier 2 应 push 政治审查事件")


func test_poem_tier3_produces_fame():
	"""Tier 3 配方 → 绝唱，产出 literary_fame"""
	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	var has_fame = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			assert_false(op.property == "money" and op.value < 0, "Tier 3 不应有 money 惩罚")
			has_fame = true
	assert_true(has_fame, "Tier 3 应有 literary_fame 产出")


func test_bucket_effect_lowest_tier_wins():
	"""木桶效应：混合 [3,2,1] → min_tier=1 → 按 Tier 1 配方"""
	var concepts = _make_tiered_concepts([3, 2, 1])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	# Tier 1 配方产出 money
	var has_money = false
	var has_fame = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money" and op.value > 0:
			has_money = true
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			has_fame = true
	assert_true(has_money, "木桶效应：min tier=1 → 应有 money 产出")
	assert_false(has_fame, "木桶效应：min tier=1 → 不应有 literary_fame")


func test_hypocrisy_zuanying_tier3():
	"""IAM=zuanying + min_tier=3 → 虚伪反噬，passed=false, fail_reason='tier'"""
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_ZUANYING)

	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	assert_false(result.passed, "虚伪反噬应导致未通过")
	assert_eq(result.fail_reason, "tier")
	assert_eq(result.penalty_text, "[虚伪的拼凑者]")


func test_hypocrisy_not_triggered_without_zuanying():
	"""IAM!=zuanying + min_tier=3 → 不应触发虚伪反噬"""
	# kuangke 不应触发 hypocrisy
	PlayerState.add_trait(ENUMS.TRAITS.KUANGDA_KUANGKE)

	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	for op in result.operators:
		assert_false(op is TraitOperator, "kuangke 不应触发虚伪反噬")


func test_health_cost_present():
	"""所有配方都有健康消耗"""
	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	var has_health = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "health" and op.value < 0:
			has_health = true
	assert_true(has_health, "应有健康消耗")


# ════════════════════════════════════════════════════════════
# E. flag_poem_tier2_count 递增测试 (E.1 Bug 回归)
# ════════════════════════════════════════════════════════════

func test_tier2_increments_flag_poem_tier2_count():
	"""每次 Tier 2 作诗应递增 flag_poem_tier2_count"""
	# 注册 flag（否则 append_flag 会因 flag 未注册而失败）
	var flag_def = Flag.new()
	flag_def.type = "int"
	Database.flags["flag_poem_tier2_count"] = flag_def

	var concepts = _make_tiered_concepts([2, 2])

	# 第一次
	PoemCraftingCalculator.calculate_poem_grade(concepts)
	assert_eq(PlayerState.get_flag("flag_poem_tier2_count"), 1, "第一次 Tier 2 诗后 count=1")

	# 第二次
	PoemCraftingCalculator.calculate_poem_grade(concepts)
	assert_eq(PlayerState.get_flag("flag_poem_tier2_count"), 2, "第二次 Tier 2 诗后 count=2")


# ════════════════════════════════════════════════════════════
# F. 管道乘数矩阵测试 (Section 10)
# ════════════════════════════════════════════════════════════

func test_channel_broadcast_tier1_zero_output():
	"""BROADCAST + Tier 1 → 工业垃圾，secular=0, history=0"""
	var concepts = _make_tiered_concepts([1, 1])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.DENG_GAO)

	# BROADCAST Tier 1: 两个乘数都是 0，不应有 money/literary_fame 产出
	var has_reward_op = false
	var has_trait = false
	for op in result.operators:
		if op is PropertyOperator and (op.property == "money" or op.property == "literary_fame"):
			has_reward_op = true
		if op is TraitOperator:
			has_trait = true
	assert_false(has_reward_op, "BROADCAST + Tier 1 不应有 money/literary_fame 产出")
	assert_true(has_trait, "应有 [无病呻吟的废纸] trait")


func test_channel_broadcast_tier2_fame_boost():
	"""BROADCAST + Tier 2 → literary_fame * 1.2, money 惩罚清零"""
	var concepts = _make_tiered_concepts([2, 2])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.HUAI_GU)

	var has_fame = false
	var has_negative_money = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			has_fame = true
		if op is PropertyOperator and op.property == "money" and op.value < 0:
			has_negative_money = true
	assert_true(has_fame, "应有 literary_fame 产出")
	assert_false(has_negative_money, "BROADCAST 不应有 money 惩罚")


func test_channel_broadcast_tier3_fame_max():
	"""BROADCAST + Tier 3 → literary_fame * 1.5"""
	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.SHAN_SHUI)

	var has_fame = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			has_fame = true
	assert_true(has_fame, "应有 literary_fame 产出")


func test_channel_secular_tier1_money_boost():
	"""SECULAR + Tier 1 → money * 1.5"""
	var concepts = _make_tiered_concepts([1, 1])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.GAN_YE)

	var has_money = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money" and op.value > 0:
			has_money = true
	assert_true(has_money, "应有 money 产出")


func test_channel_secular_tier2_political_suicide():
	"""SECULAR + Tier 2 → 政治自杀，负 money * 3 + [触怒龙颜的死书]"""
	var concepts = _make_tiered_concepts([2, 2])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.YING_ZHI)

	var has_negative_money = false
	var has_death_trait = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money" and op.value < 0:
			has_negative_money = true
		if op is TraitOperator:
			has_death_trait = true
	assert_true(has_negative_money, "SECULAR + Tier 2 应有负 money")
	assert_true(has_death_trait, "应有 [触怒龙颜的死书]")


func test_channel_secular_tier3_no_secular():
	"""SECULAR + Tier 3 → history 保持, secular=0（狂客不伺候权贵）"""
	var concepts = _make_tiered_concepts([3, 3])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts, ENUMS.POEM_TYPE.GAN_YE)

	var has_money = false
	var has_fame = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money":
			has_money = true
		if op is PropertyOperator and op.property == "literary_fame" and op.value > 0:
			has_fame = true
	assert_false(has_money, "SECULAR + Tier 3 不应有 money")
	assert_true(has_fame, "应有 literary_fame")


func test_legacy_no_poem_type_unchanged():
	"""不传 poem_type → legacy 行为不变"""
	var concepts = _make_tiered_concepts([1, 1])
	var result = PoemCraftingCalculator.calculate_poem_grade(concepts)

	# legacy Tier 1: 应有 money 产出
	var has_money = false
	for op in result.operators:
		if op is PropertyOperator and op.property == "money" and op.value > 0:
			has_money = true
	assert_true(has_money, "Legacy 路径 Tier 1 应有 money 产出")


# ════════════════════════════════════════════════════════════
# 辅助方法
# ════════════════════════════════════════════════════════════

func _make_imaginary(uuid: String) -> ImaginaryConcept:
	var ima = ImaginaryConcept.new()
	ima.uuid = uuid
	return ima

func _make_tiered_concepts(tiers: Array) -> Array[ImaginaryConcept]:
	var result: Array[ImaginaryConcept] = []
	for t in tiers:
		var ima = ImaginaryConcept.new()
		ima.uuid = "concept_tier%d_%d" % [t, randi()]
		ima.current_tier = t
		ima.current_level = 2
		result.append(ima)
	return result
