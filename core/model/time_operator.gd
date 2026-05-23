class_name TimeOperator extends BaseOperator

@export var day: float = 10.0
@export var _source_tags: Array[ENUMS.ACTION_TAGS] = []
var source_tags: Array[String] = []:
	get():
		var result: Array[String] = []
		for tag in _source_tags:
			var tag_str = ENUMS.to_action_str(tag)
			var normalized_tag = TagManager.normalize_3part_depreciated_tag(tag_str)
			result.append(normalized_tag)
		return result

func operate():
	PlayerState.current_action_tags = source_tags
	TimeService.advance_time(int(day))
	Logging.info('Time change by %s days, new year: %s' % [day, GameState.year])
	PlayerState.current_action_tags.clear()
