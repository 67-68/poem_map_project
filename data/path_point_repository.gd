class_name PathPointRepository extends BaseRepository

var type: PoetLifePoint

func get_by_id(uuid: String) -> PoetLifePoint:
    return _data.get(uuid,null)

func get_all_as_array() -> Array[PoetLifePoint]:
    return _data.values()