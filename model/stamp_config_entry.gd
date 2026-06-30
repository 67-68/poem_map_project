class_name StampConfigEntry extends Resource

@export var grade: Poem.PoemGrade
@export var stamp_data: StampData

func _init(data: Dictionary = {}):
	if data.is_empty(): return
	grade = data.get("grade", Poem.PoemGrade.JUECHANG)
	stamp_data = StampData.new()
