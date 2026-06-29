# ════════════════════════════════════════════════════════════
# FragmentMatcher 单元测试
# 覆盖：expand() / match() / collect_player_tags()
# ════════════════════════════════════════════════════════════
extends GutTest


func before_each():
	Database.imaginaries_detail.clear()
	Database.imaginaries.clear()


func _expand_all(tags: Array) -> Array[String]:
	var result: Array[String] = []
	for t in tags:
		var expanded = FragmentMatcher.expand(t)
		for e in expanded:
			if not result.has(e):
				result.append(e)
	return result

func _make_imaginary(uuid: String, tags: Array[String]) -> Imaginary:
	var imag = Imaginary.new()
	imag.uuid = uuid
	imag.detail_imaginaries = tags
	return imag


# ════════════════════════════════════════════════════════════
# A. FragmentMatcher.expand() 测试
# ════════════════════════════════════════════════════════════

func test_expand_four_segment_tag():
	var result = FragmentMatcher.expand("ENV:NATURE:AUTUMN:changanleaf")
	assert_eq(result.size(), 4, "四段 tag 应产出 4 层前缀")
	assert_eq(result[0], "ENV")
	assert_eq(result[1], "ENV:NATURE")
	assert_eq(result[2], "ENV:NATURE:AUTUMN")
	assert_eq(result[3], "ENV:NATURE:AUTUMN:changanleaf")


func test_expand_single_segment():
	var result = FragmentMatcher.expand("ENV")
	assert_eq(result.size(), 1)
	assert_eq(result[0], "ENV")


func test_expand_two_segments():
	var result = FragmentMatcher.expand("VIBE:THEME")
	assert_eq(result.size(), 2)
	assert_eq(result[0], "VIBE")
	assert_eq(result[1], "VIBE:THEME")


func test_expand_three_segments():
	var result = FragmentMatcher.expand("ENV:NATURE:GRASS")
	assert_eq(result.size(), 3)
	assert_eq(result[0], "ENV")
	assert_eq(result[1], "ENV:NATURE")
	assert_eq(result[2], "ENV:NATURE:GRASS")


func test_expand_empty_string():
	var result = FragmentMatcher.expand("")
	assert_eq(result.size(), 0, "空字符串应返回空数组")

func test_expand_special_chars():
	var result = FragmentMatcher.expand("ACTOR:DUFU:HOME:thatched-cottage")
	assert_eq(result.size(), 4)
	assert_eq(result[3], "ACTOR:DUFU:HOME:thatched-cottage")


# ════════════════════════════════════════════════════════════
# B. FragmentMatcher.match() — 权重累加测试
# ════════════════════════════════════════════════════════════

func test_match_all_exact():
	var player_tags = _expand_all([
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire",
		"ACTOR:DUFU:EMOTION:nostalgia"
	])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire",
		"ACTOR:DUFU:EMOTION:nostalgia"
	]
	assert_eq(FragmentMatcher.match(player_tags, required), 60, "3 条精确 → 20*3=60")


func test_match_all_partial():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:beijingleaf"])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"ENV:NATURE:AUTUMN:luoyangleaf",
		"ENV:NATURE:AUTUMN:nanjingleaf"
	]
	assert_eq(FragmentMatcher.match(player_tags, required), 30, "3 条同类 → 10*3=30")


func test_match_mixed_exact_partial():
	var player_tags = _expand_all([
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:wrongname"
	])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire"
	]
	assert_eq(FragmentMatcher.match(player_tags, required), 30, "20+10=30 刚过线")


func test_match_exact_no_double_count():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:changanleaf"])
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	assert_eq(FragmentMatcher.match(player_tags, required), 20, "精确命中只计 20，不同时计同类 10")


func test_match_partial_when_4th_segment_differs():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:otherleaf"])
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	assert_eq(FragmentMatcher.match(player_tags, required), 10, "第四段不同 → 退化为同类 10")


func test_match_two_segment_only():
	var player_tags = FragmentMatcher.expand("ENV:NATURE")
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	assert_eq(FragmentMatcher.match(player_tags, required), 10, "只到 2 段也是同类 10")


func test_match_no_match_at_all():
	var player_tags = _expand_all(["ENV:NATURE:GRASS:weed"])
	var required: Array[String] = ["VIBE:THEME:MACABRE:ghostfire"]
	assert_eq(FragmentMatcher.match(player_tags, required), 0, "毫无关联 → 0")


func test_match_insufficient_weight():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:beijingleaf"])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"ENV:NATURE:AUTUMN:luoyangleaf"
	]
	var w = FragmentMatcher.match(player_tags, required)
	assert_eq(w, 20, "只有 2 条同类 → 20 < 30")


func test_match_exactly_threshold():
	var player_tags = _expand_all([
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:wrongname"
	])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"VIBE:THEME:MACABRE:ghostfire"
	]
	assert_eq(FragmentMatcher.match(player_tags, required), FragmentMatcher.THRESHOLD, "恰好 30")


func test_match_empty_player_tags():
	var player_tags: Array[String] = []
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	assert_eq(FragmentMatcher.match(player_tags, required), 0, "空玩家集 → 0")


func test_match_empty_required():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:changanleaf"])
	var required: Array[String] = []
	assert_eq(FragmentMatcher.match(player_tags, required), 0, "空需求 → 0")


func test_match_duplicate_required():
	var player_tags = _expand_all(["ENV:NATURE:AUTUMN:changanleaf"])
	var required: Array[String] = [
		"ENV:NATURE:AUTUMN:changanleaf",
		"ENV:NATURE:AUTUMN:changanleaf"
	]
	assert_eq(FragmentMatcher.match(player_tags, required), 40, "重复需求各自计分 → 40")

func test_match_best_level_priority():
	var player_tags = _expand_all([
		"ENV:NATURE:AUTUMN:changanleaf"
	])
	var required: Array[String] = ["ENV:NATURE:AUTUMN:changanleaf"]
	assert_eq(FragmentMatcher.match(player_tags, required), 20, "有四段精确 → 20，不退化到 10")


# ════════════════════════════════════════════════════════════
# C. FragmentMatcher.collect_player_tags() 测试
# ════════════════════════════════════════════════════════════

func test_collect_player_tags_multiple_imaginaries():
	var im1 = _make_imaginary("leaf", ["ENV:NATURE:AUTUMN:changanleaf"])
	var im2 = _make_imaginary("ghost", ["VIBE:THEME:MACABRE:ghostfire"])
	Database.imaginaries_detail["leaf"] = im1
	Database.imaginaries_detail["ghost"] = im2

	var tags = FragmentMatcher.collect_player_tags(Database.imaginaries_detail)
	assert_true(tags.has("ENV:NATURE:AUTUMN:changanleaf"), "应包含 im1 的完整 tag")
	assert_true(tags.has("VIBE:THEME:MACABRE:ghostfire"), "应包含 im2 的完整 tag")
	assert_true(tags.has("ENV"), "应包含膨胀后的单段前缀")
	assert_true(tags.has("VIBE:THEME"), "应包含膨胀后的两段前缀")


func test_collect_player_tags_deduplication():
	var im1 = _make_imaginary("a", ["ENV:NATURE:AUTUMN:leaf"])
	var im2 = _make_imaginary("b", ["ENV:NATURE:AUTUMN:leaf"])
	Database.imaginaries_detail["a"] = im1
	Database.imaginaries_detail["b"] = im2

	var tags = FragmentMatcher.collect_player_tags(Database.imaginaries_detail)
	var count = 0
	for t in tags:
		if t == "ENV":
			count += 1
	assert_eq(count, 1, "ENV 去重后只应出现一次")


func test_collect_player_tags_empty_database():
	var tags = FragmentMatcher.collect_player_tags(Database.imaginaries_detail)
	assert_eq(tags.size(), 0, "空数据库 → 空数组")


func test_collect_player_tags_skips_non_imaginary():
	Database.imaginaries_detail["not_imag"] = {}
	var tags = FragmentMatcher.collect_player_tags(Database.imaginaries_detail)
	assert_eq(tags.size(), 0, "非 Imaginary 类型应被跳过")


func test_collect_player_tags_empty_detail_imaginaries():
	var im = _make_imaginary("empty", [])
	Database.imaginaries_detail["empty"] = im
	var tags = FragmentMatcher.collect_player_tags(Database.imaginaries_detail)
	assert_eq(tags.size(), 0, "空 detail_imaginaries → 空结果")
