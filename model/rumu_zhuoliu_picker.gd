class_name RumuZhuoliuPicker extends ArchetypeEventPicker
## 入幕·浊流 — 通过权贵/宦官门路进入幕府。
## _archetypes 和 _fallback_map 由具体数据填充。

func _init() -> void:
	_archetypes = [
		"rumu_zhuoliu_talent_to_momentum",
		"rumu_zhuoliu_poem_to_momentum",
		"rumu_zhuoliu_talent_to_money",
	]
	_fallback_map = {
		"rumu_zhuoliu_talent_to_momentum": "event_cooldown_wall",
		"rumu_zhuoliu_poem_to_momentum": "event_cooldown_wall",
		"rumu_zhuoliu_talent_to_money": "event_cooldown_wall",
	}
	_outcome = "success"
	Logging.info("[RumuZhuoliuPicker] 初始化完成，_archetypes=%d 项" % _archetypes.size())
