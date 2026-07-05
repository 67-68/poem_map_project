@tool
class_name ImaginaryLevelRewardOperator extends BaseOperator

## V7: 意象名望奖励 — ImaginaryConcept 已删除，遍历 imaginaries_detail 中的 Imaginary
## T1 奖励 (世俗)
@export var t1_fame: int = 0
## T2 奖励 (诗史)
@export var t2_fame: int = 20


func operate():
	Logging.debug("ImaginaryLevelRewardOperator: Starting operate() — V7 Imaginary picker")
	var data: Array[Imaginary] = []
	for imag in Database.imaginaries_detail.values():
		if imag is Imaginary:
			data.append(imag)

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
	Logging.info("ImaginaryLevelRewardOperator: Imaginary picked - '%s' (V7: 固定 T1 奖励)" % uuid)

	PlayerState.append_stat("literary_fame", t1_fame)
	Logging.info("ImaginaryLevelRewardOperator: T1 reward applied: fame=%d" % t1_fame)
