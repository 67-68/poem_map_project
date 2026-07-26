class_name RumuQingliuPicker extends ArchetypeEventPicker
## 入幕·清流 — 通过清流文人引荐进入幕府。
## _archetypes 和 _fallback_map 由具体数据填充。

func _init() -> void:
	_archetypes = [
		"rumu_qingliu_money_to_prestige",
		"rumu_qingliu_money_to_talent",
		"rumu_qingliu_health_to_prestige",
		"rumu_qingliu_health_to_talent",
	]
	_fallback_map = {
		"rumu_qingliu_money_to_prestige": "rumu_qingliu_fallback",
		"rumu_qingliu_money_to_talent": "rumu_qingliu_fallback",
		"rumu_qingliu_health_to_prestige": "rumu_qingliu_fallback",
		"rumu_qingliu_health_to_talent": "rumu_qingliu_fallback",
	}
	_outcome = "success"
	Logging.info("[RumuQingliuPicker] 初始化完成，_archetypes=%d 项" % _archetypes.size())
