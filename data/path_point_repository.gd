class_name PathPointRepository extends BaseRepository

var model_class = PoetLifePoint

func get_by_id(uuid: String) -> Resource:
    return super.get_by_id(uuid)

func get_all_as_array() -> Array[Resource]:
    return _data.values()