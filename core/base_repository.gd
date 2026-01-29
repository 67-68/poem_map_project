class_name BaseRepository extends RefCounted

var _data: Dictionary
var caches: Dictionary 

# dict[BaseModel,dict[uuid(本地repo的): list[uuid(other repo)]]]

func _init(data: Array[GameEntity]):
    for d in data:
        _data[d.uuid] = d

func get_by_id(uuid: String):
    var data_ = _data
    print(data_)
    print(_data)
    return data_.get(uuid,null)

func get_all():
    return _data

func get_all_as_array():
    return _data.values()

func get_first() -> GameEntity:
    for i in _data:
        return _data[i]
    return

func build_up_cache(data_service, dataclass_to_build):
    """
    dataclass to build: 各种resource, 按理来说会有一个owner_uuid
    创建一个数据模型到另一个数据模型的uuid
    比如可以知道这个诗人对应着的诗词
    """
    for base_model in dataclass_to_build:
        var repo = data_service.get_repository(base_model.repo_id)
        if not 'owner_uuids' in repo.get_first(): continue
        create_cache_for_model(base_model)
        for model_data in repo.get_all().values():
            for uuid in model_data.owner_uuids:
                if uuid in _data:
                    caches[base_model][uuid].append(model_data.uuid)
                    print("Cache append: ", base_model, " uuid: ", uuid, " model_data.uuid: ", model_data.uuid)

func create_cache_for_model(data_model):
    caches[data_model] = {}
    for d in _data.values():
        caches[data_model][d.uuid] = []

func add_record(data):
    _data[data.uuid] = data

func get_item_cache(base_model,uuid):
    return caches[base_model][uuid]