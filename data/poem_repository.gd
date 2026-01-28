class_name PoemRepository extends BaseRepository

var type: PoemData

func get_by_id(uuid: String) -> PoemData:
    return _data.get(uuid,null)

func get_all_as_array() -> Array[PoemData]:
    return _data.values()