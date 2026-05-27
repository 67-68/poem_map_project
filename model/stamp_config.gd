class_name StampConfig extends Resource

@export var _data: Array[StampConfigEntry] = []

func get_config(data: PoemData.Poem_Grade):
	for entry in _data:
		if entry.grade == data:
			return entry.stamp_data
	return null
