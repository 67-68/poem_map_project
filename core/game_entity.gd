class_name  GameEntity extends Resource

@export var uuid: String
@export var name: String
@export var description: String
@export var icon: Texture2D
@export var owner_uuids: Array
@export var tags: Array

func _init(data: Dictionary):
    uuid = data.get('uuid')
    name = data.get('name','')
    var property = data.get('property',{})
    if not property: property = data.get('properties',{})

    if not name: name = property.get('title','')
    description = data.get('description','')
    icon = IconLoader.get_icon(name)
    owner_uuids = data.get('owner_uuids',[])
    
    tags = data.get('tags',[])

    if not owner_uuids: owner_uuids = property.get('owner_uuids', [])
    if not description: description = property.get('text','')
    if not tags: tags = property.get('tags',[])
    

    

    
