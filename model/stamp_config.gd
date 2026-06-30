class_name StampConfig extends Resource

@export var _data: Array[StampConfigEntry] = []

func get_config(grade: Poem.PoemGrade):
	for entry in _data:
		if entry.grade == grade:
			return entry.stamp_data
	return null
