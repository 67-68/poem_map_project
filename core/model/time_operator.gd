class_name TimeOperator extends BaseOperator

@export var day: float
@export var _source_tags: Array[ENUMS.ACTION_TAGS] = []
var source_tags: Array[String] = []:
	get():
		return _source_tags.map(func(tag: ENUMS.ACTION_TAGS) -> String:
			return ENUMS.to_str(tag))

func operate():
	PlayerState.current_action_tags = source_tags
	TimeService.advance_time(int(day))
	Logging.info('Time change by %s days, new year: %s' % [day, Global.year])
	PlayerState.current_action_tags.clear()