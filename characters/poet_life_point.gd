extends Resource
class_name PoetLifePoint

# 每个路径点
# 从Concept notes获取

@export var id: String
@export var name: String
@export var description: String
@export var position: Vector2
@export var emotion: float
@export var owner_uuid: String
@export var point_year: float

func _init(life_point_note) -> void:
    id = life_point_note.get('uuid')
    name = life_point_note.get('title')
    description = life_point_note.get('text')
    
    var properties = life_point_note.get('properties')
    position = Vector2(properties.get('position')[0],properties.get('position')[1])
    emotion = properties.get('emotion')
    owner_uuid = properties.get('owner_uuid')
    point_year = float(properties.get('time'))