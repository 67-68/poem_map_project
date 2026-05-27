class_name StampConfigEntry extends Resource

@export var grade: PoemData.Poem_Grade
@export var stamp_data: StampData

func _init(data: Dictionary = {}):
	if data.is_empty(): return
	grade = data.get("grade", PoemData.Poem_Grade.JUECHANG)
	stamp_data = StampData.new()
