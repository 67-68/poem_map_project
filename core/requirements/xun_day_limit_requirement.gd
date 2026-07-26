@tool
class_name XunDayLimitRequirement extends BaseRequirements
## XunDayLimitRequirement — 限制行动在每旬的前 N 天可用。
## TimeService.current_day 是 0-based（0~9），max_day 是闭区间上限。
## 例如 max_day=4 表示 0,1,2,3,4（即前5天）可用。

## 旬内最大天数索引（0-based，闭区间）。默认 4 = 前5天（0,1,2,3,4）。
@export var max_day: int = 4

func describe_requirement() -> String:
	# 将 0-based max_day 转为人类可读的 1-based 天数
	var human_day: int = max_day + 1
	return tr("CODE_XUN_DAY_LIMIT_REQUIREMENT_DESC") % human_day

func compare(_player_state: PlayerState) -> bool:
	var current_day: int = TimeService.current_day
	var result: bool = current_day <= max_day
	Logging.debug("XunDayLimitRequirement: current_day=%d, max_day=%d → %s" % [current_day, max_day, "PASS" if result else "FAIL"])
	return result
