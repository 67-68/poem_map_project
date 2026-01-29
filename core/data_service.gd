class_name DataService extends Node
var _repositories: Dictionary

enum Repositories{
    POEM_REPO,
    POET_REPO,
    PATH_POINT_REPO
}

func _ready() -> void:
    

    # 暂时就在这里创建所有的repo和加载数据
    # when use PoetLifePoint/PoemData -owner_uuid-> poet_data
    _repositories[Repositories.POEM_REPO] = PoemRepository.new(DataLoader.load_data_model(PoemData,"poem_data"))
    _repositories[Repositories.POET_REPO] = PoetRepository.new(DataLoader.load_data_model(PoetData,"poet_data"))
    _repositories[Repositories.PATH_POINT_REPO] = PathPointRepository.new(DataLoader.load_data_model(PoetLifePoint,"path_points"))

    _repositories[Repositories.POET_REPO].build_up_cache(self,[PoemData,PoetLifePoint])

func get_repository(type_) -> BaseRepository:
    return _repositories.get(Repositories.get(type_),null)

func resolve_uuid(base_model,uuid):
    return _repositories[base_model].get_by_id(uuid)

