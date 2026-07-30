@tool
class_name ImaginaryCountRequirement extends BaseRequirements
## ImaginaryCountRequirement — 检查玩家拥有的意象数量是否达到阈值。
##
## @export threshold: 最小意象数量。

@export var threshold: int = 3

func compare(_player_state) -> bool:
	var count := Database.imaginaries_detail.size()
	var result := count >= threshold
	Logging.info("ImaginaryCountRequirement.compare: current=%d, threshold=%d → %s" % [count, threshold, str(result)])
	return result

func describe_requirement() -> String:
	return tr("CODE_IMAGINARY_COUNT_REQ_DESC") % threshold

func get_failed_hint() -> String:
	return tr("CODE_IMAGINARY_COUNT_REQ_FAILED") % [threshold, Database.imaginaries_detail.size()]
