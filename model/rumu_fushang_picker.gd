class_name RumuFushangPicker extends ArchetypeEventPicker
## 入幕·富商 — 通过商人/金钱铺路进入幕府。
## _archetypes 和 _fallback_map 由具体数据填充。

func _init() -> void:
	_archetypes = [
		"rumu_fushang_talent_to_money",
		"rumu_fushang_poem_to_momentum",
		"rumu_fushang_poem_to_prestige",
	]
	_fallback_map = {
		"rumu_fushang_talent_to_money": "rumu_fushang_fallback",
		"rumu_fushang_poem_to_momentum": "rumu_fushang_fallback",
		"rumu_fushang_poem_to_prestige": "rumu_fushang_fallback",
	}
	_outcome = "success"
	Logging.info("[RumuFushangPicker] 初始化完成，_archetypes=%d 项" % _archetypes.size())
