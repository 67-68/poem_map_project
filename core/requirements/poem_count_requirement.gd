@tool
class_name PoemCountRequirement extends BaseRequirements
## PoemCountRequirement — 检查玩家已创作的诗词数量是否达到阈值。
##
## @export threshold: 最小诗词数量。

@export var threshold: int = 1

func compare(_player_state) -> bool:
	var count := PlayerState.created_poems.size()
	var result := count >= threshold
	Logging.info("PoemCountRequirement.compare: current=%d, threshold=%d → %s" % [count, threshold, str(result)])
	return result

func describe_requirement() -> String:
	return tr("CODE_POEM_COUNT_REQ_DESC") % threshold

func get_failed_hint() -> String:
	return tr("CODE_POEM_COUNT_REQ_FAILED") % [threshold, PlayerState.created_poems.size()]
