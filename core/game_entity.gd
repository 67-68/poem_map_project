class_name  GameEntity extends Resource

@export var uuid: String
@export var name: String
@export var description: String
@export var icon: Texture2D
@export var owner_uuids: Array[String]
@export var tags: Array[String]

func _init(data: Dictionary):
    uuid = data.get('uuid')
    name = data.get('name',null)
    description = data.get('description',null)
    var property = data.get('property')
    icon = IconLoader.get_icon(name)
    owner_uuids = data.get('owner_uuids',[])
    tags = data.get('tags',[])

    if not name: name = property.get('title',null)
    if not description: description = property.get('text',null)
    if not owner_uuids: owner_uuids = property.get('owner_uuids',[])
    if not tags: tags = property.get('tags',[])
    

    

    
