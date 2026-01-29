class_name PoetLifePoint extends WorldEvent

@export var emotion: float
static var repo_id = "PATH_POINT_REPO"
func _init(notes):
    super._init(notes)
    emotion = notes.get('properties',{}).get('emotion',0)
    