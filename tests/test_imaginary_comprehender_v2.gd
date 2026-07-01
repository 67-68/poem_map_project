# TODO: 需要根据新的意象系统重写测试 (Imagery Simplification Refactor 2026-07-01)
# _derive_concept_groups 已从四段式 Tag 解析改为直接读 Imaginary.concepts
# 测试中四段式 tag 如 "ENV:NATURE:AUTUMN:leaf" 需改为 concept key 如 "environment:snow"
# ════════════════════════════════════════════════════════════
# ImaginaryComprehender V2 单元测试 (重构后)
# 覆盖：_derive_concept_groups / can_merge / merge_category / consume_concepts
# ════════════════════════════════════════════════════════════
extends GutTest


func before_each():
	Database.imaginaries_detail.clear()
	Database.imaginaries.clear()


func _make_imaginary(uuid: String, tags: Array[String]) -> Imaginary:
	var imag = Imaginary.new()
	imag.uuid = uuid
	imag.concepts = tags
	return imag

func _setup_imaginary_concept(key: String, tier: int = 0, level: int = 0) -> ImaginaryConcept:
	var concept = ImaginaryConcept.new()
	concept.uuid = key
	if tier > 0:
		concept.current_tier = tier
	concept.current_level = level
	Database.imaginaries[key] = concept
	return concept


# ════════════════════════════════════════════════════════════
# A. _derive_concept_groups() 动态推导测试
# ════════════════════════════════════════════════════════════

func test_derive_single_imaginary_single_concept():
	var im = _make_imaginary("leaf", ["ENV:NATURE:AUTUMN:changanleaf"])
	Database.imaginaries_detail["leaf"] = im

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups.size(), 1, "应推导出 1 个 concept group")
	assert_true(groups.has("nature:autumn"), "concept key = 中间两段小写")
	assert_eq(groups["nature:autumn"].size(), 1, "该 group 含 1 个 Imaginary")


func test_derive_two_imaginaries_same_concept():
	var im1 = _make_imaginary("leaf", ["ENV:NATURE:AUTUMN:changanleaf"])
	var im2 = _make_imaginary("wind", ["ENV:NATURE:AUTUMN:autumnwind"])
	Database.imaginaries_detail["leaf"] = im1
	Database.imaginaries_detail["wind"] = im2

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups.size(), 1, "同一个 concept")
	assert_eq(groups["nature:autumn"].size(), 2, "2 个 Imaginary 引用同一 concept")


func test_derive_multiple_concepts():
	var im1 = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf", "VIBE:THEME:MACABRE:ghost"])
	Database.imaginaries_detail["a"] = im1

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups.size(), 2, "一个 Imaginary 有 2 个不同 concept → 2 个 group")
	assert_true(groups.has("nature:autumn"))
	assert_true(groups.has("theme:macabre"))


func test_derive_ignores_tags_with_less_than_four_segments():
	var im = _make_imaginary("bad", ["ENV:NATURE:AUTUMN", "ENV:NATURE"])
	Database.imaginaries_detail["bad"] = im

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups.size(), 0, "少于 4 段的 tag 应被忽略")


func test_derive_skips_non_imaginary_entries():
	Database.imaginaries_detail["not_imag"] = {}
	Database.imaginaries_detail["also_not"] = 42

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups.size(), 0, "非 Imaginary 类型应被跳过")

func test_derive_deduplicates_same_imaginary():
	var im = _make_imaginary("dup", [
		"ENV:NATURE:AUTUMN:leaf",
		"ENV:NATURE:AUTUMN:wind"
	])
	Database.imaginaries_detail["dup"] = im

	var groups = ImaginaryComprehender._derive_concept_groups()
	assert_eq(groups["nature:autumn"].size(), 1, "同一 Imaginary 在不同 detail tag 中只计一次")


# ════════════════════════════════════════════════════════════
# B. can_merge() / can_merge_category() 合并门槛测试
# ════════════════════════════════════════════════════════════

func test_can_merge_true_with_two_imaginaries():
	_setup_imaginary_concept("nature:autumn")
	var im1 = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	var im2 = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])
	Database.imaginaries_detail["a"] = im1
	Database.imaginaries_detail["b"] = im2

	assert_true(ImaginaryComprehender.can_merge("nature:autumn"), "2 个 Imaginary → 可合并")


func test_can_merge_false_with_one_imaginary():
	_setup_imaginary_concept("nature:autumn")
	var im = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["a"] = im

	assert_false(ImaginaryComprehender.can_merge("nature:autumn"), "1 个 Imaginary → 不可合并")


func test_can_merge_false_nonexistent_concept():
	assert_false(ImaginaryComprehender.can_merge("nonexistent:concept"), "不存在的 concept → false")


func test_can_merge_true_with_three_imaginaries():
	_setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])
	Database.imaginaries_detail["c"] = _make_imaginary("c", ["ENV:NATURE:AUTUMN:rain"])

	assert_true(ImaginaryComprehender.can_merge("nature:autumn"), "3 个 Imaginary → 可合并")

func test_can_merge_category_alias():
	"""can_merge_category 是 can_merge 的别名"""
	_setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	assert_true(ImaginaryComprehender.can_merge_category("nature:autumn"), "别名接口应返回相同结果")


# ════════════════════════════════════════════════════════════
# C. merge_category() / comprehend_category() 合并坍缩测试
# ════════════════════════════════════════════════════════════

func test_merge_category_success_sets_level():
	var concept = _setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	var ok = ImaginaryComprehender.merge_category("nature:autumn")
	assert_true(ok, "合并应成功")
	assert_eq(concept.current_level, 2, "2 个 Imaginary → level=2")


func test_merge_category_sets_tier_default():
	var concept = _setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	ImaginaryComprehender.merge_category("nature:autumn")
	assert_eq(concept.current_tier, 1, "未配置 tier 时默认 1")


func test_merge_category_preserves_preconfigured_tier():
	var concept = _setup_imaginary_concept("nature:autumn", 3)
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	ImaginaryComprehender.merge_category("nature:autumn")
	assert_eq(concept.current_tier, 3, "预配置 tier=3 不应被覆盖")


func test_merge_category_consumes_imaginaries():
	_setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	assert_true(Database.imaginaries_detail.has("a"), "合并前 a 存在")
	ImaginaryComprehender.merge_category("nature:autumn")
	assert_false(Database.imaginaries_detail.has("a"), "合并后 a 被消耗")
	assert_false(Database.imaginaries_detail.has("b"), "合并后 b 被消耗")


func test_merge_category_populates_merged_backup():
	var concept = _setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", [
		"ENV:NATURE:AUTUMN:leaf",
		"VIBE:THEME:MACABRE:leaf"
	])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	ImaginaryComprehender.merge_category("nature:autumn")
	assert_eq(concept.merged.size(), 2, "merged 应包含 2 条匹配的四段 tag (leaf+wind)")
	assert_true(concept.merged.has("ENV:NATURE:AUTUMN:leaf"))
	assert_true(concept.merged.has("ENV:NATURE:AUTUMN:wind"))
	assert_false(concept.merged.has("VIBE:THEME:MACABRE:leaf"), "不匹配 concept 的 tag 不应进入 merged")


func test_merge_category_rejects_insufficient_fragments():
	_setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])

	var ok = ImaginaryComprehender.merge_category("nature:autumn")
	assert_false(ok, "1 个 Imaginary < l2_threshold → 拒绝")
	assert_true(Database.imaginaries_detail.has("a"), "碎片不应被消耗")


func test_merge_category_rejects_already_merged():
	var concept = _setup_imaginary_concept("nature:autumn", 2)  # tier != 0
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	var ok = ImaginaryComprehender.merge_category("nature:autumn")
	assert_false(ok, "已合并的 concept (tier!=0) 不应重复合并")


func test_merge_category_rejects_nonexistent_concept():
	var ok = ImaginaryComprehender.merge_category("nonexistent:concept")
	assert_false(ok, "不存在的 concept → 返回 false")


func test_merge_category_level_clamp_at_2():
	var concept = _setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])
	Database.imaginaries_detail["c"] = _make_imaginary("c", ["ENV:NATURE:AUTUMN:rain"])
	Database.imaginaries_detail["d"] = _make_imaginary("d", ["ENV:NATURE:AUTUMN:snow"])

	var ok = ImaginaryComprehender.merge_category("nature:autumn")
	assert_true(ok)
	assert_eq(concept.current_level, 2, "4 个 Imaginary → level clamp 到 2")

func test_comprehend_category_alias():
	"""comprehend_category 是 merge_category 的旧别名"""
	_setup_imaginary_concept("nature:autumn")
	Database.imaginaries_detail["a"] = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["b"] = _make_imaginary("b", ["ENV:NATURE:AUTUMN:wind"])

	var ok = ImaginaryComprehender.comprehend_category("nature:autumn")
	assert_true(ok, "别名接口应正常工作")


# ════════════════════════════════════════════════════════════
# D. consume_concepts() 阅后即焚测试
# ════════════════════════════════════════════════════════════

func test_consume_concepts_removes_from_imaginaries():
	var c1 = _setup_imaginary_concept("nature:autumn", 2, 2)
	var c2 = _setup_imaginary_concept("theme:macabre", 1, 1)

	assert_true(Database.imaginaries.has("nature:autumn"), "删除前应存在")
	ImaginaryComprehender.consume_concepts([c1, c2])
	assert_false(Database.imaginaries.has("nature:autumn"), "c1 应被删除")
	assert_false(Database.imaginaries.has("theme:macabre"), "c2 应被删除")


func test_consume_concepts_handles_non_concept_entries():
	"""非 ImaginaryConcept 条目应被安全跳过"""
	var c1 = _setup_imaginary_concept("nature:autumn", 2, 2)
	var not_concept = {}
	ImaginaryComprehender.consume_concepts([c1, not_concept])
	assert_false(Database.imaginaries.has("nature:autumn"), "c1 应被删除")


func test_consume_concepts_empty_array():
	ImaginaryComprehender.consume_concepts([])
	# 不应崩溃（无断言，验证不抛异常即通过）
	assert_true(true)




