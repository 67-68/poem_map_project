class_name FragmentMatcher extends RefCounted

## 诗词意象匹配引擎 — 基于 concept 直接匹配
##
## concept 格式：两段式，如 "environment:snow"
## 匹配规则：玩家池全集 ∩ 诗词 required_fragments → 精确=20, 前缀=10, 累加≥30 通过

const EXACT_WEIGHT := 20   ## 完整匹配（如 "environment:snow" == "environment:snow"）
const PARTIAL_WEIGHT := 10 ## 概念前缀匹配（如 "environment" 匹配 "environment:snow"）
const THRESHOLD := 30      ## 通过门槛


## 遍历玩家拥有的所有 Imaginary，收集其 concepts 的并集
static func collect_player_tags(imaginaries_detail: Dictionary) -> Array[String]:
	var all_tags: Dictionary = {}
	for imag in imaginaries_detail.values():
		if not (imag is Imaginary):
			continue
		for ck in imag.concepts:
			all_tags[ck.to_lower()] = true
	var result: Array[String] = []
	for key in all_tags:
		result.append(key)
	return result


## 按概念分组匹配：诗词的每个 required_fragment 在玩家选中的 concept 池中找匹配
## concepts: 选中的 ImaginaryConcept 数组
## required_fragments: 需要的 concept uuid 列表（现在是两段式，如 "environment:snow"）
static func match_concepts(concepts: Array, required_fragments: Array[String]) -> int:
	# 构建玩家池：concepts 下所有 Imaginary 的 concepts 并集
	var pool_set: Dictionary = {}
	for concept in concepts:
		if not (concept is ImaginaryConcept):
			continue
		for imag in ImaginaryComprehender.get_imaginaries_for_concept(concept.uuid):
			for ck in imag.concepts:
				pool_set[ck.to_lower()] = true

	var total_weight := 0
	for req in required_fragments:
		req = req.to_lower()
		if pool_set.has(req):
			total_weight += EXACT_WEIGHT  # 完整匹配
		else:
			# 尝试前缀匹配：检查是否有 concept 以 req + ":" 开头
			# 例如 req="environment" 匹配 "environment:snow"
			var partial_matched := false
			for pool_key in pool_set:
				if pool_key.begins_with(req + ":"):
					partial_matched = true
					break
			if partial_matched:
				total_weight += PARTIAL_WEIGHT

	return total_weight
