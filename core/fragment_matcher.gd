class_name FragmentMatcher extends RefCounted

## 诗词意象匹配引擎 — 加载时膨胀 + 运行时 Set 交集 + 权重累加
##
## 膨胀规则: "ENV:NATURE:AUTUMN:changanleaf" → ["ENV", "ENV:NATURE", "ENV:NATURE:AUTUMN", "ENV:NATURE:AUTUMN:changanleaf"]
## 匹配规则: 玩家 expanded_tags Set ∩ 诗词 required_fragments 膨胀 Set → 精确=20, 同类=10, 累加≥30 通过

const EXACT_WEIGHT := 20   ## 4 段完全一致
const PARTIAL_WEIGHT := 10 ## 前 3 段一致
const THRESHOLD := 30      ## 通过门槛


## 加载时膨胀: 将四段式 Tag 展开为所有层级前缀
## "A:B:C:D" → ["A", "A:B", "A:B:C", "A:B:C:D"]
static func expand(tag: String) -> Array[String]:
	if tag.is_empty():
		return []
	var parts := tag.split(":")
	var result: Array[String] = []
	var current := ""
	for i in range(parts.size()):
		if not current.is_empty():
			current += ":"
		current += parts[i]
		result.append(current)
	return result


## 运行时匹配: 玩家持有的 expanded_tags 与诗词要求的 required_fragments 做 Set 交集
## 每条 required_fragment 只取最精确匹配的一层（从完整四段向下找），不重复计分
## 返回累计权重
static func match(player_expanded: Array[String], required_fragments: Array[String]) -> int:
	# Godot 4 无原生 Set，用 Dictionary key 模拟 O(1) 查找
	var player_set: Dictionary = {}
	for t in player_expanded:
		player_set[t] = true

	var total_weight := 0

	for req in required_fragments:
		var req_expanded := expand(req)
		# 从最精确层级（四段）向下找，取第一个命中
		var matched := false
		for i in range(req_expanded.size() - 1, -1, -1):
			if player_set.has(req_expanded[i]):
				var level := i + 1  # 1-indexed: 1段=最模糊, 4段=精确
				if level == 4:
					total_weight += EXACT_WEIGHT
				else:
					total_weight += PARTIAL_WEIGHT
				matched = true
				break  # 一条 required_fragment 只计一次
		# 无匹配 → 0，不计数

	return total_weight


## 遍历玩家拥有的所有 Imaginary，收集其 expanded_tags 的并集
static func collect_player_tags(imaginaries_detail: Dictionary) -> Array[String]:
	var all_tags: Dictionary = {}  # 用 dict key 去重
	for imag in imaginaries_detail.values():
		if not (imag is Imaginary):
			continue
		for tag in imag.detail_imaginaries:
			var expanded := expand(tag)
			for t in expanded:
				all_tags[t] = true

	var result: Array[String] = []
	for key in all_tags:
		result.append(key)
	return result


## 单条 Imaginary 的 detail_imaginaries 与 required_fragments 匹配
## 取该 Imaginary 所有 detail_imaginary 中最高的一条权重
static func _match_single_imaginary(imag: Imaginary, required_fragments: Array[String]) -> int:
	if not imag:
		return 0
	var best := 0
	for tag in imag.detail_imaginaries:
		var expanded := expand(tag)
		var tag_set: Dictionary = {}
		for t in expanded:
			tag_set[t] = true

		for req in required_fragments:
			var req_expanded := expand(req)
			for i in range(req_expanded.size() - 1, -1, -1):
				if tag_set.has(req_expanded[i]):
					var level := i + 1
					if level == 4:
						best = max(best, EXACT_WEIGHT)
					else:
						best = max(best, PARTIAL_WEIGHT)
					break
	return best


## 按概念分组匹配：诗词的每个 required_fragment 在玩家选中的 3 个 concept 的全量 Imaginary 池中找最高分，累加
## concepts: 选中的 ImaginaryConcept 数组
## required_fragments: 诗词需要的四段式 Tag 列表
static func match_concepts(concepts: Array, required_fragments: Array[String]) -> int:
	# 构建玩家池：3 个 concept 下所有 Imaginary 的 expanded_tags 并集（去重）
	var pool_set: Dictionary = {}
	var pool_imaginaries: Array[Imaginary] = []
	for concept in concepts:
		if not (concept is ImaginaryConcept):
			continue
		for imag in ImaginaryComprehender.get_imaginaries_for_concept(concept.uuid):
			if not pool_imaginaries.has(imag):
				pool_imaginaries.append(imag)
			for tag in imag.detail_imaginaries:
				var expanded := expand(tag)
				for t in expanded:
					pool_set[t] = true

	# 对诗词的每个 required_fragment，在池子中找最高匹配
	var total_weight := 0
	for req in required_fragments:
		var best := 0
		var req_expanded := expand(req)
		# 从最精确层级向下找
		for i in range(req_expanded.size() - 1, -1, -1):
			if pool_set.has(req_expanded[i]):
				var level := i + 1
				if level == 4:
					best = EXACT_WEIGHT
				else:
					best = PARTIAL_WEIGHT
				break
		total_weight += best

	return total_weight
