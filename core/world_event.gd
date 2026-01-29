class_name WorldEvent extends GameEntity
var position: Vector2
var year: int
var location_uuid: String

func _init(data: Dictionary):
    super._init(data)
    position = data.get('position',Vector2(0,0))
    year = data.get('year',Global.start_year)
    location_uuid = data.get('location_uuid','')

    var property = data.get('property',{})
    if not position:
        position = property.get('position',Vector2(0,0))
    if not year:
        # 也检查 "time" 属性，因为 path_points.json 使用 "time"
        year = property.get('time', Global.start_year)
        if year == Global.start_year:
            year = property.get('year', Global.start_year)
    if not location_uuid:
        location_uuid = property.get('location_uuid','')