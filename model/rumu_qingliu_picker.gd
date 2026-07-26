class_name RumuQingliuPicker extends ArchetypeEventPicker
## 入幕·清流 — 通过清流文人引荐进入幕府。
## _archetypes 和 _fallback_map 由具体数据填充。

func _init() -> void:
	_archetypes = [
		# TODO: 填充清流入幕 archetype keys
	]
	_fallback_map = {
		# TODO: archetype_key → fallback_event_uuid
	}
	_outcome = "success"
	Logging.info("[RumuQingliuPicker] 初始化完成，_archetypes=%d 项" % _archetypes.size())
