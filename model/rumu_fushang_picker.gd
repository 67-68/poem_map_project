class_name RumuFushangPicker extends ArchetypeEventPicker
## 入幕·富商 — 通过商人/金钱铺路进入幕府。
## _archetypes 和 _fallback_map 由具体数据填充。

func _init() -> void:
	_archetypes = [
		# TODO: 填充富商入幕 archetype keys
	]
	_fallback_map = {
		# TODO: archetype_key → fallback_event_uuid
	}
	_outcome = "success"
	Logging.info("[RumuFushangPicker] 初始化完成，_archetypes=%d 项" % _archetypes.size())
