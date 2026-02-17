class_name ChoiceResult extends GameEntity

var target_uuid := ''

func _init(data = {}):
	if Logging.not_exists('choice_result',data):
		return
	super._init(data)
	target_uuid = PropParser.parse_any(data,true,'target_uuid')

	