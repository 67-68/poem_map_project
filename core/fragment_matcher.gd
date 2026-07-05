class_name FragmentMatcher extends RefCounted

## 诗词意象匹配引擎 V7 — 纯精确 Set 匹配 imaginary uuid
##
## V7 变更: ImaginaryConcept 已删除，输入直接为 imaginary uuid 数组。
## 只有精确 Set 匹配（3/3），不再有打油诗/subset/向后兼容。


## 将 imaginary uuid 数组排序后拼接为食谱索引 key
## 例: ["snow", "cold_moon", "falling_leaf"] → "cold_moon|falling_leaf|snow"
static func build_key(uuids: Array[String]) -> String:
	var sorted = uuids.duplicate()
	sorted.sort()
	return "|".join(sorted)


## 判断 submitted Set 是否完全等于 required Set（无序）
static func is_exact_match(submitted: Array[String], required: Array[String]) -> bool:
	if submitted.size() != required.size():
		return false

	var required_set: Dictionary = {}
	for r in required:
		required_set[r.to_lower()] = true

	for s in submitted:
		if not required_set.has(s.to_lower()):
			return false
	return true
