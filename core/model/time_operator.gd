@tool
class_name TimeOperator extends BaseOperator
## 时间操作器。通过 PlayerState 接口修改 time 属性。
## 外部仅能操作 _time，PlayerState 内部将其映射到 time。

@export var day: float = 10.0
@export var refresh_time = false
@export var refresh_time_to = 10

func operate():
	if refresh_time_to:
		var ok: bool = PlayerState.set_stat_val("_time", refresh_time_to)
		if not ok:
			Logging.err('TimeOperator: refresh_time failed, PlayerState.set_stat_val("_time", x) returned false')
			return
		Logging.info('restore time')
		return
		
	if refresh_time:
		var ok: bool = PlayerState.set_stat_val("_time", 10)
		if not ok:
			Logging.err('TimeOperator: refresh_time failed, PlayerState.set_stat_val("_time", 10) returned false')
			return
		Logging.info('restore time to 10')
		return
	var actual_day: int = max(0, int(day))
	
	# 先消耗 time stat，再推进日历。
	Logging.info('TimeOperator: 消耗 %d 天, 再推进日历' % actual_day)
	var ok: bool = PlayerState.append_stat("_time", -actual_day)
	if not ok:
		Logging.err('TimeOperator: 消耗 %d 天失败，PlayerState.append_stat("_time", %d) returned false，日历不推进' % [actual_day, -actual_day])
		return
	TimeService.advance_time(actual_day)
	Logging.info('TimeOperator: 消耗 %d 天完成，已推进日历' % actual_day)

func describe_preview() -> String:
	if refresh_time:
		return ""
	if day <= 0:
		return ""
	return tr("CODE_TIME_OPERATOR_8AD92110DA") % int(day)
