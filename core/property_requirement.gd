class_name PropertyRequirement extends GameEntity
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
var front_property_name: String
var front_property_data: int
var operator: String
var failed_hint: String # 在
var oringinal_str: String

func get_property_from_str(prop_str: String):
	var splited = prop_str.split(":")
	return splited

func _init(data: Dictionary): # 类似 A>123
	super._init(data)
	var text = PropParser.parse_any(data,true,'requirement')
	oringinal_str = text
	var failed_hint_ = PropParser.parse_any(data,true,'failed_hint')
	if not (text and failed_hint_):
		Logging.err('some prop requirement dont have failed hint or text')
		breakpoint
		return

	failed_hint = failed_hint_
	var splited_text = text.split("<")
	if !(splited_text[0] == text): operator = '<'
	else:  
		splited_text = text.split(">")
		if !(splited_text[0] == text): operator = '>'
		else: Logging.err('property requirement %s can not be parsed' % data)
	
	front_property_name = splited_text[0]
	front_property_data = int(splited_text[1])
	
	Logging.info('property requirement %s parsed' % data)

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat(front_property_name)
	if not (stat_front):
		Logging.err('do not found stat %s in player stat, check pronounciation' % front_property_name)
		return 
	if operator == '<':
		return stat_front < front_property_data
	else:
		return stat_front > front_property_data
	

func get_fail_prop_msg():
	var to_replace = ">" if operator == "<" else "<"
	return oringinal_str.replace(operator,to_replace)
