@tool
class_name TimeOperator extends BaseOperator
## 时间操作器。通过 PlayerState 接口修改 time 属性。
## 外部仅能操作 _time，PlayerState 内部将其映射到 time。

@export var day: float = 10.0

func operate():
	var actual_day: int = max(0, int(day))
	PlayerState.append_stat("_time", -actual_day)
	TimeService.advance_time(actual_day)
	Logging.info('TimeOperator: 消耗 %d 天，调用 TimeService.advance_time(%d)' % [actual_day, actual_day])
