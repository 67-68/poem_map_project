class_name PropStagedPerceptionData extends Resource

@export var stage_val: int = 0
@export var perception_text: String = ""

func _init(val: int, text: String):
    stage_val = val
    perception_text = text