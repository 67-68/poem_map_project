class_name ChoiceResult extends GameEntity

var target_uuid: String = ''
var action_type: String = ''
var stat_operator: StatOperator = null

func _init(data = {}):
	if Logging.not_exists('choice_result',data):
		return
	super._init(data)
	target_uuid = PropParser.parse_any(data,true,'target_uuid')
	action_type = PropParser.parse_any(data,true,'action_type')
	if action_type == 'trait': 
		stat_operator = PropParser.parse_and_create_cls(TraitOperator,data,true,'stat_operator')
	elif action_type == 'property':
		stat_operator = PropParser.parse_and_create_cls(PropertyOperator,data,true,'stat_operator')
	else:
		Logging.err('do not found type %s for stat operator' % action_type)


	
