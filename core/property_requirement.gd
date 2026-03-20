class_name PropertyRequirement extends RefCounted
# 在选项中使用，用来判断某个player state的property是否达标

# 单个property requirement
var front_property_name: String
var front_property_data: int
var back_property_name: String
var back_property_data: int
var operator: String

func get_property_from_str(prop_str: String):
	var splited = prop_str.split(":")
	return splited

func _init(data: String): # 类似 A:123>B:234
	var splited = data.split("<")
	if not splited: 
		splited = data.split(">")
	if not splited:
		Logging.err('property requirement %s can not be parsed' % data)
	
	var front_prop = get_property_from_str(splited[0])
	var back_prop = get_property_from_str(splited[1])
	front_property_name = front_prop[0]
	front_property_data = front_prop[1]
	back_property_name = back_prop[0]
	back_property_data = back_prop[1]
	Logging.info('property requirement %s parsed' % data)

func compare(player_state: PlayerState):
	var stat_front = player_state.get_stat(front_property_name)
	var stat_back = player_state.get_stat(back_property_name)
	if not (stat_front and stat_back):
		Logging.err('do not found stat %s and %s in player stat, check pronounciation' % [stat_front, stat_back])
		return 
	
