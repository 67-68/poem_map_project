class_name DataService extends Node
var _repositories: Dictionary

func _ready() -> void:
    # 暂时就在这里创建所有的repo和加载数据
    # when use PoetLifePoint/PoemData -owner_uuid-> poet_data
    for item in [PoetLifePoint,PoemData,PoetData]:
        var file_path = "res://data/%s" % str(item)
        var data = DataLoader.load_data_model(item,file_path)
        _repositories[item] = BaseRepository.new(item,data)

func get_repository(type: GDScript):
    return _repositories.get(type,null)


