class_name FragmentMatcher extends RefCounted

## 诗词意象匹配引擎 V5 — 精确 Set 匹配 + 2/3 子集检测
##
## 输入直接为两段式 concept uuid，不做任何字符串处理。
## 与 PoemCraftingCalculator 配合使用：calculator 负责食谱索引查找，
## FragmentMatcher 提供纯 Set 比较工具函数。

const MATCH_EXACT := 3      ## 3/3 精确匹配
const MATCH_PARTIAL := 2    ## 2/3 子集匹配


## 将 concept uuid 数组排序后拼接为食谱索引 key
## 例: ["emotion:ambition", "aesthetic:elegant", "society:famine"]
##   → "aesthetic:elegant|emotion:ambition|society:famine"
static func build_key(concept_uuids: Array[String]) -> String:
	var sorted = concept_uuids.duplicate()
	sorted.sort()
	return "|".join(sorted)


## 统计 submitted 中有多少个 concept uuid 命中 required 集合
## submitted: 玩家提交的 concept uuid 数组
## required: 食谱的 required_fragments 数组
## 返回 0-3 的匹配数量
static func count_matches(submitted: Array[String], required: Array[String]) -> int:
	var required_set: Dictionary = {}
	for r in required:
		required_set[r.to_lower()] = true

	var count := 0
	for s in submitted:
		if required_set.has(s.to_lower()):
			count += 1
	return count


## 判断 submitted Set 是否完全等于 required Set（无序）
static func is_exact_match(submitted: Array[String], required: Array[String]) -> bool:
	if submitted.size() != required.size():
		return false
	return count_matches(submitted, required) == submitted.size()


## 向后兼容：旧接口 match_concepts（V4 加权评分 → V5 精确匹配桥接）
## concepts: ImaginaryConcept 数组
## required_fragments: 食谱所需的 concept uuid 列表
## 返回: MATCH_EXACT(3) 精确匹配 / MATCH_PARTIAL(2) 子集匹配 / <2 无匹配
static func match_concepts(concepts: Array, required_fragments: Array[String]) -> int:
	var submitted: Array[String] = []
	for concept in concepts:
		if concept is ImaginaryConcept:
			submitted.append(concept.uuid.to_lower())
	return count_matches(submitted, required_fragments)


## V4 向后兼容常量
const EXACT_WEIGHT := 20
const PARTIAL_WEIGHT := 10
const THRESHOLD := 30


## V4 向后兼容：收集玩家所有 Imaginary 的 concepts 并集
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
