@tool
class_name ImaginaryLevelRewardOperator extends BaseOperator

## V6: 意象 Tier 名望奖励 — 基于 current_tier 而非已删除的 current_level
## T1 奖励 (世俗)
@export var t1_fame: int = 0
## T2 奖励 (诗史)
@export var t2_fame: int = 20


func operate():
	Logging.debug("ImaginaryLevelRewardOperator: Starting operate() — tier-based reward")
	var data = []
	for uuid in Database.get_imaginaries_all():
		var imaginary = Database.get_imaginaries_all()[uuid] as ImaginaryConcept
		if not imaginary:
			continue
		if imaginary.current_tier < 1:
			continue
		data.append(imaginary)

	Logging.debug("ImaginaryLevelRewardOperator: Found %d available imaginaries" % data.size())

	if data.is_empty():
		Logging.warn("ImaginaryLevelRewardOperator: No imaginaries available, nothing to show")
		return

	EventBus.push_picker.emit(data, _on_imaginary_picked, null)


func _on_imaginary_picked(imaginary_picked):
	if not imaginary_picked:
		Logging.warn("ImaginaryLevelRewardOperator: No imaginary picked, skipping reward")
		return

	var uuid = imaginary_picked.uuid
	var tier = imaginary_picked.current_tier
	Logging.info("ImaginaryLevelRewardOperator: Imaginary picked - '%s' (tier=%d)" % [uuid, tier])

	match tier:
		2:
			PlayerState.append_stat("literary_fame", t2_fame)
			Logging.info("ImaginaryLevelRewardOperator: T2 reward applied: fame=%d" % t2_fame)
		1:
			PlayerState.append_stat("literary_fame", t1_fame)
			Logging.info("ImaginaryLevelRewardOperator: T1 reward applied: fame=%d" % t1_fame)
		_:
			Logging.warn("ImaginaryLevelRewardOperator: unknown tier %d, no reward applied" % tier)
