class_name PoetLifePoint extends WorldEvent

@export var emotion: float
@export var owner_uuid: String

func _init(notes) -> void:
    super._init(notes)
    emotion = notes.get('properties').get('emotion')
    