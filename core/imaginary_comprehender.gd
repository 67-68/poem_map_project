class_name ImaginaryComprehender extends RefCounted

## 感悟坍缩：将 category 下的 basic_imaginaries 坍缩为 tier/level
## 返回 true 表示坍缩成功，false 表示条件不足（碎片不够或 category 不存在）
static func comprehend_category(category_id: String) -> bool:
	var ima = Database.get_imaginary(category_id) as ImaginaryTag
	if not ima:
		return false

	var fragments = ima.basic_imaginaries
	if fragments.size() < ImaginaryTag.l2_threshold:
		return false

	# 墨水污染定律：一证永证 — tier 取所有碎片中的最低值
	var final_tier = 999
	for frag in fragments:
		var t = frag.get("tier", 1)
		final_tier = mini(final_tier, t)

	# level: fragments.size() clamp 到 0-2
	var final_level = mini(fragments.size(), 2)

	# 销毁底层碎片
	ima.basic_imaginaries.clear()

	# 写入坍缩结果
	ima.current_tier = final_tier
	ima.current_level = final_level

	return true


## 阅后即焚：诗词创作后删除投入的概念
static func consume_concepts(concepts: Array[ImaginaryTag]):
	for c in concepts:
		if c:
			Database.imaginaries.erase(c.uuid)
