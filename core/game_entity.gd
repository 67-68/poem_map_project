class_name  GameEntity extends Resource

@export var uuid: String
@export var name: String
@export var description: String
@export var icon: Texture2D

func _init(data: Dictionary):
    uuid = data.get('uuid')
    name = data.get('name',null)
    if not name: name = data.get('title',null)

    description = data.get('description',null)
    if not description: description = data.get('text',null)

    icon = IconLoader.get_icon(name)
