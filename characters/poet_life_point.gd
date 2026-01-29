class_name PoetLifePoint extends WorldEvent

@export var emotion: float

func _init(notes) -> void:
    super._init(notes)
    emotion = notes.get('properties').get('emotion')
    