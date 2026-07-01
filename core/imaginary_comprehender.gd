class_name ImaginaryComprehender extends RefCounted

## 意象感悟引擎 — 动态交叉推导 + 合并坍缩
##
## 核心原理：遍历玩家拥有的所有 Imaginary，
## 从它们的 concepts 字段中动态推导出哪些 abstract concept 被多少碎片引用。
##
## 合并门槛：≥2 个 Imaginary 引用同一 abstract concept → 可合并
## 可见门槛：≥1 个 Imaginary 引用 → 在 PoemCrafter 中可见（但不可合并）


## 动态推导：遍历所有 Imaginary，按 abstract_concept 分组计数
## 返回: Dictionary[concept_key → Array[Imaginary]]
static func _derive_concept_groups() -> Dictionary:
	var groups: Dictionary = {}  # concept_key → Array[Imaginary]

	for imag in Database.imaginaries_detail.values():
		if not (imag is Imaginary):
			continue
		for concept_key in imag.concepts:
			concept_key = concept_key.to_lower()
			if not groups.has(concept_key):
				groups[concept_key] = []
			var group: Array = groups[concept_key]
			if not group.has(imag):
				group.append(imag)

	return groups


## 获取所有活跃的 ImaginaryConcept（被 Imaginary 引用 或 已合并 tier>0）
static func get_active_concepts() -> Dictionary:
	var active: Dictionary = {}
	var groups = _derive_concept_groups()

	for concept_key in groups:
		var concept = Database.get_imaginary(concept_key)
		if not concept:
			continue
		active[concept_key] = concept

	# 也纳入已合并但无碎片的概念（tier > 0）
	for uuid in Database.imaginaries:
		var concept = Database.imaginaries[uuid] as ImaginaryConcept
		if not concept or concept.current_tier <= 0:
			continue
		if not active.has(uuid):
			active[uuid] = concept

	return active


## 获取指定 concept 下的所有关联 Imaginary（用于 PoemCrafter 展示 OrbitDetail）
static func get_imaginaries_for_concept(concept_key: String) -> Array:
	var groups = _derive_concept_groups()
	return groups.get(concept_key, [])


## 检查某个 concept 是否可以合并（≥2 个 Imaginary 引用）
static func can_merge(concept_key: String) -> bool:
	var groups = _derive_concept_groups()
	var group: Array = groups.get(concept_key, [])
	return group.size() >= ImaginaryConcept.l2_threshold


## 合并坍缩：消耗引用该 concept 的所有 Imaginary，提升 concept 的 level
## 返回 true 表示合并成功
static func merge_category(concept_key: String) -> bool:
	var concept = Database.get_imaginary(concept_key) as ImaginaryConcept
	if not concept:
		Logging.err("ImaginaryComprehender.merge_category: concept '%s' not found" % concept_key)
		return false

	# 获取引用该 concept 的所有 Imaginary
	var imaginaries = get_imaginaries_for_concept(concept_key)
	if imaginaries.size() < ImaginaryConcept.l2_threshold:
		Logging.warn("ImaginaryComprehender.merge_category: concept '%s' 碎片不足 (%d < %d)" %
			[concept_key, imaginaries.size(), ImaginaryConcept.l2_threshold])
		return false

	# 禁止重复合并
	if concept.current_tier != 0:
		Logging.warn("ImaginaryComprehender.merge_category: concept '%s' 已合并 (tier=%d)，禁止重复合并" %
			[concept_key, concept.current_tier])
		return false

	# 收集匹配该 concept_key 的所有 concept 作为 merged 备份
	var merged_tags: Array[String] = []
	for imag in imaginaries:
		for ck in imag.concepts:
			if ck.to_lower() == concept_key:
				merged_tags.append(ck)

	# 计算 level（clamp 到 0-2）
	var final_level = mini(imaginaries.size(), 2)
	var old_level = concept.current_level

	# 保存备份并更新
	concept.merged = merged_tags
	concept.current_level = final_level
	# tier 保持 ImaginaryConcept 资源文件中预配置的值不变（如未配置则默认 1）
	if concept.current_tier == 0:
		concept.current_tier = 1

	# 消耗 Imaginaries
	for imag in imaginaries:
		Database.imaginaries_detail.erase(imag.uuid)

	if final_level != old_level:
		Logging.info("ImaginaryComprehender.merge_category: '%s' level %d→%d，消耗 %d 个 Imaginary" %
			[concept_key, old_level, final_level, imaginaries.size()])
		EventBus.imaginary_changed.emit()

	Logging.info("ImaginaryComprehender.merge_category: '%s' 合并成功 (tier=%d, level=%d, merged_tags=%d)" %
		[concept_key, concept.current_tier, concept.current_level, merged_tags.size()])
	return true


## 感悟坍缩（旧接口兼容）：等同于合并，但使用旧的 comprehend 语义
static func comprehend_category(category_id: String) -> bool:
	return merge_category(category_id)


## 非破坏性检查：是否满足合并前提
static func can_merge_category(category_id: String) -> bool:
	return can_merge(category_id)


## 阅后即焚：诗词创作后消耗投入的概念
## 删除玩家已收集的 Imaginary 碎片（imaginaries_detail），
## 重置 ImaginaryConcept 的运行时状态（tier/level/merged），
## 但保留静态定义（Database.imaginaries）不被删除。
static func consume_concepts(concepts: Array):
	for c in concepts:
		if not (c and c is ImaginaryConcept):
			continue
		var concept = c as ImaginaryConcept

		# 1. 删除所有引用该概念的 Imaginary 碎片
		var to_erase: Array[String] = []
		for imag_key in Database.imaginaries_detail:
			var imag = Database.imaginaries_detail[imag_key]
			if imag is Imaginary and concept.uuid in imag.concepts:
				to_erase.append(imag_key)
		for key in to_erase:
			Database.imaginaries_detail.erase(key)

		# 2. 重置概念运行时状态（保留静态定义不被删除）
		concept.current_tier = 0
		concept.current_level = 0
		concept.merged = []
