class_name WorldEvent extends GameEntity
var position: Vector2
var year: int
var location_uuid: String

func _init(data: Dictionary):
    super._init(data)

    var property = data.get('property',{})

    position = property.get('position',Vector2(0,0))
    year = property.get('year',Global.start_year)
    location_uuid = property.get('location_uuid','')