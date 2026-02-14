class_name StampConfig extends Resource

@export var _data: Dictionary[PoemData.Poem_Grade,StampData] = {}

func get_config(data: PoemData.Poem_Grade):
	print("Dictionary Keys: ", _data.keys())
	return _data[data]
