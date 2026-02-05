extends GutTest

func test_process_poem_events():
	# --- 1. 准备假数据 (Mock Data) ---
	var mock_points = {
		"p1": { "year": 700, "tags": ["poem_静夜思"] },
		"p2": { "year": 705, "tags": ["normal_event"] },
		"p3": { "year": 710, "tags": ["poem_蜀道难"] }
	}
	var keys = ["p1", "p2", "p3"]
	
	# --- Case A: 正常触发诗词 ---
	# 当前目标是 700 年，应该触发静夜思，并将目标更新为 705
	var result = Util.process_poem_events(mock_points, keys, 700)
	
	assert_true(result.found_poems, "应该找到诗词")
	assert_eq(result.poems_to_emit.size(), 1, "应该有一首诗")
	assert_eq(result.poems_to_emit[0], "静夜思", "诗名提取正确")
	assert_eq(result.new_target_year, 705, "目标年份应该更新到下一个节点(705)")

	# --- Case B: 到达普通节点 (705) ---
	# 705年没有诗，但也应该把年份推到 710
	result = Util.process_poem_events(mock_points, keys, 705)
	
	assert_false(result.found_poems, "705年不该有诗")
	assert_eq(result.new_target_year, 710, "年份应该继续推进到 710")

	# --- Case C: 找不到下一个节点 (End Game) ---
	# 到了 710，后面没点了吗？(假设 p3 是最后一个)
	result = Util.process_poem_events(mock_points, keys, 710)
	
	assert_true(result.found_poems, "710年有诗")
	# 如果后面没点了，new_target_year 应该保持 710 不变，或者你需要定义一个结束标志
	assert_eq(result.new_target_year, 710, "没有下一年了，保持不变")