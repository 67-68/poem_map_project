class_name PoemRepository extends BaseRepository

var model_class = PoemData

func get_by_id(uuid: String) -> PoemData:
    return _data.get(uuid,null)

func get_all_as_array() -> Array[PoemData]:
    return _data.values()

func build_up_cache(data_service, dataclass_to_build):
    var test_uuid = 0
    super.build_up_cache(data_service, dataclass_to_build)
    var poet_repo = data_service.get_repository("POET_REPO")
    var point_repo = data_service.get_repository("PATH_POINT_REPO")
    # 判断是否已经存在

    # 创建路径点
    for d in _data:
        var life_points = poet_repo.caches[PoetLifePoint][d.owner_uuids[0]] # 目前仅为owner_uuid设计了只有一个的情况; 或者说第一个uuid是poet
        var already_have := false
        for point in life_points:
            if d.uuid in point.tags:
                already_have = true
        
        if not already_have:
            var life_point = PoetLifePoint.new(d)
            life_point.uuid = 'poem-%s' % test_uuid
            life_point.tags.append(d.uuid)
            point_repo.add_record(life_point)
            test_uuid += 1
