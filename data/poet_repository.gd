class_name PoetRepository extends BaseRepository

var type: PoetData

func get_by_id(uuid: String) -> PoetData:
    return _data.get(uuid,null)

func get_all_as_array() -> Array[PoetData]:
    return _data.values()