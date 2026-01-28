class_name PoetLifePoint extends WorldEvent

@export var emotion: float
@export var owner_uuid: String

func _init(notes) -> void:
    super._init(notes)
    var properties = notes.get('properties')
    emotion = properties.get('emotion')
    owner_uuid = properties.get('owner_uuid')