@tool
class_name ImaginaryLevelRewardOperator extends BaseOperator

## L3 名望奖励（意象等级 3 — 完美作答）
@export var l3_fame: int = 50
## L2 名望奖励（意象等级 2 — 良好作答）
@export var l2_fame: int = 20
## L1 名望奖励（意象等级 1 — 普通作答）
@export var l1_fame: int = 0


func operate():
	Logging.debug("ImaginaryLevelRewardOperator: Starting operate()")
	var data = []
	for uuid in Database.imaginaries:
		var imaginary = Database.imaginaries[uuid] as ImaginaryTag
		if not imaginary:
			continue
		if imaginary.current_level < 1:
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
	var level = imaginary_picked.current_level
	Logging.info("ImaginaryLevelRewardOperator: Imaginary picked - '%s' (level=%d)" % [uuid, level])

	match level:
		3:
			PlayerState.append_stat("literary_fame", l3_fame)
			Logging.info("ImaginaryLevelRewardOperator: L3 reward applied: fame=%d" % l3_fame)
		2:
			PlayerState.append_stat("literary_fame", l2_fame)
			Logging.info("ImaginaryLevelRewardOperator: L2 reward applied: fame=%d" % l2_fame)
		1:
			PlayerState.append_stat("literary_fame", l1_fame)
			Logging.info("ImaginaryLevelRewardOperator: L1 reward applied: fame=%d" % l1_fame)
		_:
			Logging.warn("ImaginaryLevelRewardOperator: unknown level %d, no reward applied" % level)
