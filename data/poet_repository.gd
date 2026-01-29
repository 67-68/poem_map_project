class_name PoetRepository extends BaseRepository

var model_class = PoetData
var path_point_keys := []

func get_by_id(uuid: String) -> PoetData:
    return _data.get(uuid,null)

func get_all_as_array() -> Array[PoetData]:
    return _data.values()

func setup_path_point_keys(data: PoetData,data_service):
    var uuid_list = caches[PoetLifePoint][data.uuid]
    data.path_point_keys = Util.get_sorted_keys_by_num_property(data_service.get_repository(PoetLifePoint).get_all(),'year',uuid_list)

func build_up_cache(data_service, dataclass_to_build):
    super.build_up_cache(data_service,dataclass_to_build)
    for d in _data:
        setup_path_point_keys(_data[d],data_service)