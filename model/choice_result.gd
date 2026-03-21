class_name ChoiceResult extends GameEntity

var target_uuid: String = ''
var action_type: String = ''
var operators: Array[StatOperator] = []

func _init(data = {}):
	if Logging.not_exists('choice_result',data):
		return
	super._init(data)
	var t = PropParser.parse_any(data,true,'target_uuid')
	target_uuid = t if t else ''
	var action_type_ = PropParser.parse_any(data,true,'action_type')
	action_type = action_type_ if action_type_ else ''
	
	if action_type == 'trait': 
		var trait_operator = PropParser.parse_and_create_cls(TraitOperator,data,true,'operator')
		if trait_operator:
			operators.append(trait_operator)
	elif action_type == 'property':
		var property_operator = PropParser.parse_and_create_cls(PropertyOperator,data,true,'operator')
		if property_operator:
			operators.append(property_operator)
	elif action_type == 'multi_property':
		var operators_data = PropParser.parse_any(data,true,'operators')
		if operators_data:
			for op_data in operators_data:
				var op = PropertyOperator.new(op_data)
				operators.append(op)
	elif action_type == 'time_change':
		var time_op = PropParser.parse_and_create_cls(TimeOperator,data,true,'operator')
		if time_op:
			operators.append(time_op)
	else:
		Logging.err('do not found type %s for stat operator' % action_type)

func operate():
	"""
	执行所有操作符
	"""
	for op in operators:
		if op:
			op.operate()
		else:
			Logging.warn('Found null operator in ChoiceResult')
