class_name PathPointRepository extends BaseRepository

var model_class = PoetLifePoint

func get_by_id(uuid: String) -> PoetLifePoint:
    return super.get_by_id(uuid)

func _init(data):
    super._init(data)