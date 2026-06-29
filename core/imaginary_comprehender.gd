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
	var old_level = ima.current_level
	ima.current_tier = final_tier
	ima.current_level = final_level

	if final_level != old_level:
		Logging.info("ImaginaryComprehender.comprehend_category: '%s' level 变化 %d→%d，发射信号" % [category_id, old_level, final_level])
		EventBus.imaginary_changed.emit()

	return true


## 非破坏性检查：是否满足合并前提条件（碎片 >= 2 且未合并过）
static func can_merge_category(category_id: String) -> bool:
	var ima = Database.get_imaginary(category_id) as ImaginaryTag
	if not ima:
		return false
	if ima.basic_imaginaries.size() < ImaginaryTag.l2_threshold:
		return false
	if ima.current_tier != 0:
		return false
	return true


## 合并坍缩：保留碎片副本到 merged 字段，提升等级 + 赋予 tier
## 门槛: basic_imaginaries.size() >= 2，且未合并过 (current_tier == 0)
## 返回 true 表示合并成功
static func merge_category(category_id: String) -> bool:
	var ima = Database.get_imaginary(category_id) as ImaginaryTag
	if not ima:
		Logging.err("ImaginaryComprehender.merge_category: category '%s' not found" % category_id)
		return false

	# 门槛检查：碎片 >= 2
	if ima.basic_imaginaries.size() < ImaginaryTag.l2_threshold:
		Logging.warn("ImaginaryComprehender.merge_category: category '%s' 碎片不足 (%d < %d)" %
			[category_id, ima.basic_imaginaries.size(), ImaginaryTag.l2_threshold])
		return false

	# 禁止重复合并：current_tier != 0 说明已坍缩/合并过
	if ima.current_tier != 0:
		Logging.warn("ImaginaryComprehender.merge_category: category '%s' 已合并 (tier=%d)，禁止重复合并" %
			[category_id, ima.current_tier])
		return false

	# 墨水污染定律：tier 取所有碎片中的最低值
	var final_tier = 999
	for frag in ima.basic_imaginaries:
		var t = frag.get("tier", 1)
		final_tier = mini(final_tier, t)

	# level: fragments.size() clamp 到 0-2
	var final_level = mini(ima.basic_imaginaries.size(), 2)

	# 保存完整副本到 merged 字段
	ima.merged = ima.basic_imaginaries.duplicate(true)

	# 清空碎片
	ima.basic_imaginaries.clear()

	# 写入坍缩结果
	var old_level = ima.current_level
	ima.current_tier = final_tier
	ima.current_level = final_level

	if final_level != old_level:
		Logging.info("ImaginaryComprehender.merge_category: '%s' level 变化 %d→%d，发射信号" % [category_id, old_level, final_level])
		EventBus.imaginary_changed.emit()

	Logging.info("ImaginaryComprehender.merge_category: '%s' 合并成功 (tier=%d, level=%d, fragments=%d)" %
		[category_id, final_tier, final_level, ima.merged.size()])
	return true


## 阅后即焚：诗词创作后删除投入的概念
static func consume_concepts(concepts: Array[ImaginaryTag]):
	for c in concepts:
		if c:
			Database.imaginaries.erase(c.uuid)
