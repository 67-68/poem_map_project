class_name Util extends RefCounted

static func get_highest_val_from_dict_vec2(dict: Dictionary,position: int): # position: 0/1, 比较x/y
	var max: int = 0
	for val in dict.values():
		if not max: max = val[position]
		if val[position] > max: max = val[position]
	return max
