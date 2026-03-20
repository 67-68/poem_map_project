class_name PropertyRequirement extends RefCounted
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
var front_property_name: String
var front_property_data: int
var operator: String
var failed_hint: String # 在

func get_property_from_str(prop_str: String):
	var splited = prop_str.split(":")
	return splited

func _init(data: String): # 类似 A>123
	var splited = data.split("<")
	if splited: operator = '<'
	else:  
		splited = data.split(">")
		if splited: operator = '>'
		else: Logging.err('property requirement %s can not be parsed' % data)
	
	front_property_name = splited[0]
	front_property_data = splited[1]
	Logging.info('property requirement %s parsed' % data)

func compare(player_state: PlayerState) -> bool:
	var stat_front = player_state.get_stat(front_property_name)
	if not (stat_front):
		Logging.err('do not found stat %s in player stat, check pronounciation' % stat_front)
		return 
	if operator == '<':
		return stat_front < front_property_data
	else:
		return stat_front > front_property_data
	
