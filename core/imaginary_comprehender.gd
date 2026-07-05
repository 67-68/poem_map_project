class_name ImaginaryComprehender extends RefCounted

## 意象消费工具 V7 — 扁平化意象系统
##
## V7 变更: ImaginaryConcept 已删除，不再有分组/合并/坍缩。
## 仅保留 consume_imaginaries() — 诗词创作后直接删除选中的 3 个 Imaginary。


## 阅后即焚：诗词创作后消耗选中的 3 个 Imaginary
## imaginaries: 选中的 Imaginary 数组
static func consume_imaginaries(imaginaries: Array):
	for imag in imaginaries:
		if not (imag is Imaginary):
			Logging.warn("ImaginaryComprehender.consume_imaginaries: 非 Imaginary 类型，跳过")
			continue
		var uuid = imag.uuid
		if Database.imaginaries_detail.has(uuid):
			Database.imaginaries_detail.erase(uuid)
			Logging.info("ImaginaryComprehender.consume_imaginaries: 消耗 Imaginary '%s'(%s)" % [uuid, imag.name])
		else:
			Logging.warn("ImaginaryComprehender.consume_imaginaries: Imaginary '%s' 不在 imaginaries_detail 中" % uuid)


## 向后兼容：旧接口 consume_concepts（已弃用，委托给 consume_imaginaries）
static func consume_concepts(imaginaries: Array):
	Logging.warn("ImaginaryComprehender.consume_concepts: 已弃用，请使用 consume_imaginaries")
	consume_imaginaries(imaginaries)
