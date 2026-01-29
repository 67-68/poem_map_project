class_name PoetLifePoint extends WorldEvent

@export var emotion: float = 0.5 # 给个默认值，防止心情崩溃

# 静态 ID 可以保留，用于 Repository 注册
static var repo_id = "PATH_POINT_REPO"

func _init(data: Dictionary = {}):
    # 1. 父类处理 uuid, name, position, year
    super._init(data)
    
    if data.is_empty(): return
    
    var props = data.get("properties", data.get("property", {}))
    
    # 2. 自己只处理情绪
    # 假设 emotion 是 0.0 - 1.0
    emotion = props.get("emotion", data.get("emotion", 0.5))