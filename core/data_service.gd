class_name DataService extends Node
var _repositories: Dictionary

func _ready() -> void:
    # 暂时就在这里创建所有的repo和加载数据
    # when use PoetLifePoint/PoemData -owner_uuid-> poet_data
    _repositories[PoemData] = PoemRepository.new(DataLoader.load_data_model(PoemData,"poem_data"))
    _repositories[PoetData] = PoetRepository.new(DataLoader.load_data_model(PoetData,"poet_data"))
    _repositories[PoetLifePoint] = PathPointRepository.new(DataLoader.load_data_model(PoetLifePoint,"path_points"))

    _repositories[PoetData].build_up_cache(self,[PoemData,PoetLifePoint])

func get_repository(type: GDScript) -> BaseRepository:
    return _repositories.get(type,null)


