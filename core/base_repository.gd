class_name BaseRepository extends RefCounted

var _data: Dictionary

func _init(data: Array[GameEntity]):
    for d in data:
        _data[d.uuid] = d

func get_by_id(uuid: String):
    return _data.get(uuid,null)

func get_all():
    return _data

func get_all_as_array():
    return _data.values()
